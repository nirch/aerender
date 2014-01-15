#encoding: utf-8
require 'sinatra'
require 'mongo'
require 'uri'
require 'json'
require 'fileutils'
require 'open-uri'
require 'aws-sdk'

#include Mongo

configure do
	# Setting db connection param
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	# Setting folders param
	set :aeProjectsFolder, "C:/Users/Administrator/Documents/AE Projects/"
	set :aerenderPath, "C:/Program Files/Adobe/Adobe After Effects CS6/Support Files/aerender.exe"
	set :outputFolder, "C:/Users/Administrator/Documents/AE Output/"
	set :ffmpeg_path, "C:/Development/ffmpeg/ffmpeg-20131202-git-e3d7a39-win64-static/bin/ffmpeg.exe"
	set :algo_path, "C:/Development/Algo/v-14-01-05/UniformMattingCA.exe"
	set :remakes_folder, "C:/Users/Administrator/Documents/Remakes/"

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)
end

def get_templates
	collection = settings.db.collection("Templates")
	docs = collection.find.sort({id: 1});
	parsed_array = Array.new
	for doc in docs do
		parsed_doc = JSON.parse(doc.to_json)
		parsed_array.push(parsed_doc)
	end
	templates = parsed_array
end

module RemakeStatus
  New = 0
  InProgress = 1
  Rendering = 2
  Done = 3
end

module FootageStatus
  Open = 0
  Uploaded = 1
  Processing = 2
  Ready = 3
end


# Get all stories
get '/stories' do
	stories_collection = settings.db.collection("Stories")
	stories_docs = stories_collection.find({ }, {fields: {after_effects: 0}}).sort({order_id: 1})

	stories_json_array = Array.new
	for story_doc in stories_docs do
		stories_json_array.push(story_doc.to_json)
	end

	puts "Returning " + stories_json_array.count.to_s + " stories"

	stories = "[" + stories_json_array.join(",") + "]"
	# stories = JSON[stories_docs]
end

# Creating a new remake (params are: story_id, user_id)
post '/remake' do
	# input
	story_id = BSON::ObjectId.from_string(params[:story_id])
	user_id = params[:user_id]

	remakes = settings.db.collection("Remakes")
	story = settings.db.collection("Stories").find_one(story_id)
	remake_id = BSON::ObjectId.new
	
	puts "Creating a new remake for story <" + story["name"] + "> for user <" + user_id + "> with remake_id <" + remake_id.to_s + ">"

	s3_folder = "Remakes" + "/" + remake_id.to_s + "/"
	s3_video = s3_folder + story["name"] + "_" + remake_id.to_s + ".mp4"

	remake = {_id: remake_id, story_id: story_id, user_id: user_id, status: RemakeStatus::New, thumbnail: story["thumbnail"], video_s3_key: s3_video}

	# Creating the footages place holder based on the scenes of the story
	scenes = story["scenes"]
	if scenes then
		footages = Array.new
		for scene in scenes do			
			s3_destination_raw = s3_folder + "raw_" + "scene_" + scene["id"].to_s + ".mov"
			s3_destination_processed = s3_folder + "processed_" + "scene_" + scene["id"].to_s + ".mov"
			footage = {scene_id: scene["id"], status: FootageStatus::Open, raw_video_s3_key: s3_destination_raw, processed_video_s3_key: s3_destination_processed}
			footages.push(footage)
		end
		remake[:footages] = footages
	end

	#Creating the text place holder based the texts of the storu
	texts = story["texts"]
	if texts then
		text_inputs = Array.new
		for text in texts
			text_input = {text_id: text["id"]}
			text_inputs.push(text_input)
		end
		remake[:texts] = text_inputs
	end

	# Creating a new remake document in the DB
	remake_objectId = remakes.save(remake)

	puts "New remake saved in the DB with remake id " + remake_objectId.to_s

	# Creating a new directory in the remakes folder
	#remake_folder = settings.remakes_folder + remake_objectId.to_s
	#FileUtils.mkdir remake_folder

	# Returning the remake object ID
	result = remake.to_json
end

# Deletes a given remake
delete '/remake/:remake_id' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	puts "Deleting remake " + remake_id.to_s

	settings.db.collection("Remakes").remove({_id: remake_id})
end

# Returns a given remake id
get '/remake/:remake_id' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	puts "Getting remake with id " + remake_id.to_s

	# Fetching the remake
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)

	if remake then
		remake.to_json
	else
		status 404
	end
end

# Returns all the remakes of a given user_id
get '/remakes/user/:user_id' do
	# input
	user_id = params[:user_id];

	puts "Getting remakes for user " + user_id

	remakes_docs = settings.db.collection("Remakes").find({user_id: user_id});

	remakes_json_array = Array.new
	for remake_doc in remakes_docs do
		remakes_json_array.push(remake_doc.to_json)
	end

	puts "Returning " + remakes_json_array.count.to_s + " remakes"

	remakes = "[" + remakes_json_array.join(",") + "]"
end

def upload_to_s3 (file, s3_key, acl)

	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']
	s3_object = bucket.objects[s3_key]

	puts 'Uploading the file <' + file.path + '> to S3 path <' + s3_object.key + '>'
	s3_object.write(file, :acl => acl)
	puts "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s

	return s3_object

end

def download_from_s3 (s3_key, local_path)

	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']

	puts "Downloading file from S3 with key " + s3_key
	s3_object = bucket.objects[s3_key]

	File.open(local_path, 'wb') do |file|
  		s3_object.read do |chunk|
    		file.write(chunk)
    	end
    end

  	puts "File downloaded successfully to: " + local_path
end


# Post a new footage (params are: uploaded file, remake id, scene id)
post '/footage' do
	# input
	source = params[:file][:tempfile]
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i

	new_footage source, remake_id, scene_id

end

def new_footage (video, remake_id, scene_id)

	puts "New footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s

	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)

	# Uploading to S3
	s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	upload_to_s3 video, s3_key, :private

	# Updating the DB
	remake["footages"][scene_id - 1][:"status"] = FootageStatus::Uploaded
	result = remakes.update({_id: remake_id}, remake)
	puts "DB Result: " + result.to_s

	Thread.new{
		# Running the foreground extraction algorithm
		foreground_extraction remake_id, scene_id
	}

end


def foreground_extraction (remake_id, scene_id)
	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	puts "Running foreground extraction for scene " + scene_id.to_s + " for remkae " + remake_id.to_s

	# Updating the DB that the process has started
	remake["footages"][scene_id - 1]["status"] = FootageStatus::Processing
	result = remakes.update({_id: remake_id}, remake)

	# Creating a new directory for the foreground extraction
	foreground_folder = settings.remakes_folder + remake_id.to_s + "_scene_" + scene_id.to_s + "/"
	FileUtils.mkdir foreground_folder

	# Downloading the raw video from s3
	raw_video_s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	raw_video_file_name = File.basename(raw_video_s3_key)
	raw_video_file_path = foreground_folder + raw_video_file_name	
	download_from_s3 raw_video_s3_key, raw_video_file_path

	# images from the video
	images_fodler = foreground_folder + "Images/"
	ffmpeg_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -q:v 1 "' + images_fodler + 'Image-%4d.jpg"'
	puts "*** Video to images *** \n" + ffmpeg_command
	FileUtils.mkdir images_fodler
	system(ffmpeg_command)

	# foreground extraction algorithm
	contour_path = story["scenes"][scene_id - 1]["contour"]
	roi_path = story["scenes"][scene_id - 1]["ebox"]
	first_image_path = images_fodler + "Image-0001.jpg"
	output_folder = File.dirname(raw_video_file_path) + "/" + File.basename(raw_video_file_path, ".*") + "_Foreground/"
	output_path = output_folder + "Output"
	algo_command = settings.algo_path + ' "' + contour_path + '" "' + roi_path + '" "' + first_image_path + '" -png "' + output_path + '"'
	puts "*** Running Algo *** \n" + algo_command 
	FileUtils.mkdir output_folder
	system(algo_command)

	# pngs to video
	output_file_name = "foreground_" + "scene_" + scene_id.to_s + ".mov"
	output_video_path = File.dirname(raw_video_file_path) + "/" + output_file_name
	png_convert_command = settings.ffmpeg_path + ' -i "' + output_path.chomp(File.extname(output_path)) + '-%2d.png"' + ' -vcodec png "' + output_video_path + '"'
	puts "*** png to video *** \n" + png_convert_command
	system(png_convert_command)

	# upload to s3
	processed_video_s3_key = remake["footages"][scene_id - 1]["processed_video_s3_key"]
	upload_to_s3 File.new(output_video_path), processed_video_s3_key, :private

	# Updating the DB
	remake["footages"][scene_id - 1]["status"] = FootageStatus::Ready
	remake["footages"][scene_id - 1][:processed] = output_video_path		
	result = remakes.update({_id: remake_id}, remake)	
	puts 'DB update: footage ' + scene_id.to_s + ' for remake ' + remake_id.to_s + ' status changed to Ready'

	# Deleting the folder after everything was updated successfully
	#FileUtils.remove_dir(foreground_folder)
end

=begin
# Doing the foreground extraction of the video (params: remake id, scene id)
post '/foreground' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i

	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	# Updating the DB that the process has started
	remake["footages"][scene_id - 1]["status"] = FootageStatus::Processing
	result = remakes.update({_id: remake_id}, remake)

	raw_video = remake["footages"][scene_id - 1]["raw"]

	# images from the video
	images_fodler = File.dirname(raw_video) + "/" + File.basename(raw_video, ".*") + "_Images/"
	ffmpeg_command = settings.ffmpeg_path + ' -i "' + raw_video + '" -q:v 1 "' + images_fodler + 'Image-%4d.jpg"'
	puts "*** Video to images *** \n" + ffmpeg_command

	# foreground extraction algorithm
	contour_path = story["scenes"][scene_id - 1]["contour"]
	roi_path = story["scenes"][scene_id - 1]["ebox"]
	first_image_path = images_fodler + "Image-0001.jpg"
	output_folder = File.dirname(raw_video) + "/" + File.basename(raw_video, ".*") + "_Foreground/"
	output_path = output_folder + "Output"
	algo_command = settings.algo_path + ' "' + contour_path + '" "' + roi_path + '" "' + first_image_path + '" -png "' + output_path + '"'
	puts "*** Running Algo *** \n" + algo_command 

	# pngs to video
	output_file_name = "foreground_" + "scene_" + scene_id.to_s + ".mov"
	output_video_path = File.dirname(raw_video) + "/" + output_file_name
	png_convert_command = settings.ffmpeg_path + ' -i "' + output_path.chomp(File.extname(output_path)) + '-%2d.png"' + ' -vcodec png "' + output_video_path + '"'
	puts "*** png to video *** \n" + png_convert_command

	Thread.new{
		# Creating images folder and the images
		FileUtils.mkdir images_fodler
		system(ffmpeg_command)

		# Creating algo folder and running the algo
		FileUtils.mkdir output_folder
		system(algo_command)

		# Converting pngs to video
		system(png_convert_command)

		# Deleting the images and algo folders
		#FileUtils.remove_dir(images_fodler)
		FileUtils.remove_dir(output_folder)	

		# Updating the DB that the process has started
		remake["footages"][scene_id - 1]["status"] = FootageStatus::Ready
		remake["footages"][scene_id - 1][:processed] = output_video_path		
		result = remakes.update({_id: remake_id}, remake)	
	}

end
=end

def render_video (remake_id)

	# Fetching the remake and story for this remake
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	puts "Starting the rendering of remake " + remake_id.to_s

	# Updating the DB that the process has started
	remake["status"] = RemakeStatus::Rendering
	result = remakes.update({_id: remake_id}, remake)

	# copying all videos to after project (downloading them from s3)
	for scene in story["after_effects"]["scenes"] do
		processed_video_s3_key = remake["footages"][scene["id"] - 1]["processed_video_s3_key"]
		destination = settings.aeProjectsFolder + story["after_effects"]["folder"] + "/(Footage)/" + scene["file"]
		download_from_s3 processed_video_s3_key, destination
	end

	projectPath = settings.aeProjectsFolder + story["after_effects"]["folder"] + "/" + story["after_effects"]["project"]
	output_file_name = story["name"] + "_" + remake_id.to_s + ".mp4"
	output_path = settings.outputFolder + output_file_name
	aerenderCommandLine = '"' + settings.aerenderPath + '"' + ' -project "' + projectPath + '"' + ' -rqindex 1 -output "' + output_path + '"'
	puts "aerender command line: #{aerenderCommandLine}"

	# Rendering the movie
	system(aerenderCommandLine)

	video_s3_key = remake["video_s3_key"]

	# Uploading the movie to S3
	s3_object = upload_to_s3 File.new(output_path), video_s3_key, :public_read

	# Updating the DB that the movie is readt
	remake["status"] = RemakeStatus::Done
	remake[:video] = s3_object.public_url.to_s
	result = remakes.update({_id: remake_id}, remake)

	puts "Updating DB: remake " + remake_id.to_s + " with status Done and url to video: " + s3_object.public_url.to_s

end

post '/render' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	Thread.new{
		render_video remake_id
	}
end


get '/test/remake/delete' do
	# input
	remake_id = BSON::ObjectId.from_string("52cd89ecdb25450bb8000001")

	settings.db.collection("Remakes").remove({_id: remake_id})
end

get '/test/s3/download' do

	s3_key = 'Remakes/52d57901db25451344000001/raw_scene_1.mov'
	local_path = settings.remakes_folder + File.basename(s3_key)

	download_from_s3 s3_key, local_path

end

get '/test/s3/upload' do
	form = '<form action="/test/s3/upload" method="post" enctype="multipart/form-data"> <input type="file" accept="video/*" name="file"> <input type="submit" value="Upload!"> </form>'
	erb form
end

post '/test/s3/upload' do
	file = params[:file][:tempfile]
	file_path = file.path
	s3_key = 'Temp/' + File.basename(file_path)

	s3_object = upload_to_s3 file, s3_key, :private

	puts s3_object.public_url
end

get '/test/footage' do
	form = '<form action="/test/footage" method="post" enctype="multipart/form-data"> <input type="file" accept="video/*" name="file"> <input type="submit" value="Upload!"> </form>'
	erb form
end

post '/test/footage' do
	#input
	#source = "C:/Users/Administrator/AppData/Local/Temp/2/RackMultipart20140107-3512-1fpalb1"

	file = params[:file][:tempfile]
	file_path = file.path
	remake_id = BSON::ObjectId.from_string("52d68511db25450da4000001")
	scene_id = 1

	new_footage file, remake_id, scene_id

=begin
	puts "Uploading footage for scene " + scene_id.to_s + " of remake " + remake_id.to_s

	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)

	# Copying the footage to the remake folder
	#destination_file_name = "raw_" + "scene_" + scene_id.to_s + ".mov"
	#destination = settings.remakes_folder + remake_id.to_s + "/" + destination_file_name
	#FileUtils.copy(source.path, destination)

	# Uploading the file to S3
	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']
	s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	s3_object = bucket.objects[s3_key]

	Thread.new{
		puts 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
		s3_object.write(file, :acl => :public_read)
		puts "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s

		# Updating the DB
		#remake["footages"][scene_id - 1][:raw] = destination
		remake["footages"][scene_id - 1][:"status"] = FootageStatus::Uploaded
		result = remakes.update({_id: remake_id}, remake)
		puts "DB Result: " + result.to_s
	}
=end
end


=begin
get '/test/s3upload' do
	file_name = "C:/Users/Administrator/Documents/Remakes/52cd8d9edb25450d84000001/final_Test_52cd8d9edb25450d84000001.mp4"

	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']

	bucket.objects.each do |obj|
	  #puts obj.key
	end

	basename = File.basename(file_name)
	o = bucket.objects["Final Videos/" + basename]
	o.write(:file => file_name)
	puts o.public_url
	#o.write(:file => file_name)
	#File.open("c:/image.ctr", "w") do |f|
  	#	f.write(bucket.objects['Stories/Test/Scenes/1/Test_Scene_1_Contour.ctr'].read)
	#end
end
=end

get '/test/render' do
	# input
	remake_id = BSON::ObjectId.from_string("52d6a0dcdb254505fc000001")

	Thread.new{
		render_video remake_id
	}
end

get '/test/foreground' do
	# input
	remake_id = BSON::ObjectId.from_string("52d57901db25451344000001")
	scene_id = 1

	#Thread.new{
		foreground_extraction remake_id, scene_id
	#}

end


get '/test/update/remake' do
	#input
	remake_id = BSON::ObjectId.from_string("52cd72e5db254506c0000001")
	scene_id = 1

	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	puts remake
	footages = remake["footages"]
	puts "********"
	puts footages

	footage = {scene_id: scene_id, raw: "Link", processed: "Link"}
	
	if footages then
		puts "Adding a new footage"
		footages.push(footage)
	else
		puts "Creating the footages array"
		footages = Array.new
		footages.push(footage)
	end

	remake[:footages] = footages
	result = remakes.update({_id: remake_id}, remake)

	#remake[:test] = "Testing"
	#puts remake
	#result = remakes.update({_id: remake_id}, remake)
end


get '/test/create/remake' do
	#input
	story_id = BSON::ObjectId.from_string("52cddaf80fad07c3290001aa")
	user_id = "nir@gmail.com"

	remakes = settings.db.collection("Remakes")
	story = settings.db.collection("Stories").find_one(story_id)

	puts "Creating a new remake for story <" + story["name"] + "> for user <" + user_id + ">"

	remake_id = BSON::ObjectId.new
	puts "remake_id = " + remake_id.to_s
	remake = {_id: remake_id, story_id: story_id, user_id: user_id, status: RemakeStatus::New, thumbnail: story["thumbnail"]}

	# Creating the footages place holder based on the scenes of the story
	scenes = story["scenes"]
	if scenes then
		footages = Array.new
		for scene in scenes do			
			s3_destination = "Remakes" + "/" + remake_id.to_s + "/" + "raw_" + "scene_" + scene["id"].to_s + ".mov"
			footage = {scene_id: scene["id"], status: FootageStatus::Open, raw_video_s3_key: s3_destination}
			footages.push(footage)
		end
		remake[:footages] = footages
	end

	#Creating the text place holder based the texts of the storu
	texts = story["texts"]
	if texts then
		text_inputs = Array.new
		for text in texts
			text_input = {text_id: text["id"]}
			text_inputs.push(text_input)
		end
		remake[:texts] = text_inputs
	end

	# Creating a new remake document in the DB
	remake_objectId = remakes.save(remake)

	puts "New remake saved in the DB with remake id " + remake_objectId.to_s

	# Creating a new directory in the remakes folder
	remake_folder = settings.remakes_folder + remake_objectId.to_s
	FileUtils.mkdir remake_folder

	# Returning the remake object ID
	result = remake.to_json

	#remakes = settings.db.collection("Remakes")
	#remake = {story_id: story_id, user_id: user_id}
	#remake_objectId = remakes.save(remake)
	#puts remake_objectId
end


get '/test/s3download' do

	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']
	#bucket.objects['key']

	bucket.objects.each do |obj|
	  puts obj.key
	end

	File.open("c:/image.ctr", "w") do |f|
  		f.write(bucket.objects['Stories/Test/Scenes/1/Test_Scene_1_Contour.ctr'].read)
	end

	#open('c:/image.png', 'wb') do |file|
  	#	file << open('https://s3.amazonaws.com/homageapp/Stories/Test/Scenes/1/Test_Scene_1_Silhouette.png').read
	#end
end


get '/testAlgo' do
	story_folder = "Test"
	scene_file = "test.mov"
	source = "C:/Users/ADMINI~1/AppData/Local/Temp/2/RackMultipart20140107-3512-1fpalb1"
	source_folder = File.dirname(source) + "/"
	puts source_folder
	destination_folder = settings.aeProjectsFolder + story_folder + "/(Footage)/"
	destination = destination_folder + scene_file

	# Creating images from the video
	images_fodler = source_folder + "Images/"
	FileUtils.mkdir images_fodler
	ffmpeg_command = settings.ffmpeg_path + ' -i "' + source + '" -q:v 1 "' + images_fodler + 'Image-%4d.jpg"'
	puts "*** Video to images *** \n" + ffmpeg_command
	system(ffmpeg_command)

=begin
	# Running the foreground extraction algorithm
	contour_path = folder + File.basename(file, ".*" ) + ".ctr"
	roi_path = folder + File.basename(file, ".*" ) + ".ebox"
	#roi_path = "C:/Development/Algo/Ver-13-12-08/roi.ebox"
	first_image_path = images_fodler + "Image-0001.jpg"
	output_path = folder + File.basename(file, ".*" ) + "-Foreground" + ".avi"
	algo_command = algo_path + ' "' + contour_path + '" "' + roi_path + '" "' + first_image_path + '" -avi "' + output_path + '"'
	puts "*** Running Algo *** \n" + algo_command 
	system(algo_command)

	# Converting the large avi file to a small mp4 file
	mp4_path = output_path.chomp(File.extname(output_path)) + ".mp4"
	convert_command = ffmpeg_path + ' -i "' + output_path + '" -vcodec mpeg4 -b:v 1200k "' + mp4_path + '"'
	puts "*** avi to mp4 *** \n" + convert_command
	system(convert_command)

	# Deleting the big avi file
	puts "*** Deleting avi... ***"
	FileUtils.remove_file(output_path)

	# Deleting the images directory
	puts "*** Deleting Images... ***"
	FileUtils.remove_dir(images_fodler)
=end

end

get '/templates' do
	@templates = get_templates
	erb :templates
end

get '/templates/:id' do
	# Getting the the template that matches the id in the url
	templates_collection = settings.db.collection("Templates")
	template_doc_json = templates_collection.find_one({id:params[:id].to_i}).to_json
	@template = JSON.parse(template_doc_json)
	erb :template
end

post '/upload' do
	source = params[:file][:tempfile]
	destination = settings.aeProjectsFolder + params[:template_folder] + "/(Footage)/" + params[:segment_file]
	puts destination
	FileUtils.copy(source.path, destination)

	'Uploaded!'
	#redirect back
end

post '/update_text' do
	dynamic_text_path = settings.aeProjectsFolder + params[:template_folder] + "/" + params[:dynamic_text_file]
	dynamic_text = params[:dynamic_text]
	#file_contents = "var Text = ['#{dynamic_text}'];"
	file_contents = '"' + dynamic_text + '"'

	dynamic_text_file = File.new(dynamic_text_path, "w")
    dynamic_text_file.puts(file_contents)
    dynamic_text_file.close

    'Text updated!'
    #redirect back
end

post '/render_old' do

	projectPath = settings.aeProjectsFolder + params[:template_folder] + "/" + params[:template_project]
	outputPath = settings.outputFolder +  params[:output] + ".mp4"
	aerenderCommandLine = '"' + settings.aerenderPath + '"' + ' -project "' + projectPath + '"' + ' -rqindex 1 -output "' + outputPath + '"'
	puts "areder command line: #{aerenderCommandLine}"

	#Thread.new{
		system(aerenderCommandLine)
	#}

	#redirect_to = "/download/" + params[:output] + ".mp4"
	#erb "Wait a minute, and click this link: <a href=" + redirect_to + ">" +  params[:output] + "</a>"
end

get '/download/:filename' do
	downloadPath = settings.outputFolder + params[:filename]
	puts "download file path: #{downloadPath}"
	send_file downloadPath #, :type => 'video/mp4', :disposition => 'inline'
end


################################
# Foreground extraction script #
################################

get '/foreground_old' do
	form = '<form action="/foreground" method="post" enctype="multipart/form-data"> <input type="file" accept="video/*" name="file"> <input type="submit" value="Foreground!"> </form>'
	erb form
end

post '/foreground_old' do

	foreground_folder = "C:/Users/Administrator/Documents/Foreground Extraction/"

	# Copying the file locally
	source = params[:file][:tempfile]
	folder = File.basename( params[:file][:filename], ".*" )
	destination_folder = foreground_folder + folder + "/"
	FileUtils.mkdir destination_folder
	destination = destination_folder + params[:file][:filename]
	FileUtils.copy(source.path, destination)
	puts "File copied to: " + destination

	# Creating images from the video
	ffmpeg_path = "C:/Development/ffmpeg/ffmpeg-20131202-git-e3d7a39-win64-static/bin/ffmpeg.exe"
	images_fodler = destination_folder + "Images/"
	FileUtils.mkdir images_fodler
	ffmpeg_command = ffmpeg_path + ' -i "' + destination + '" "' + images_fodler + 'Image-%4d.jpg"'
	puts ffmpeg_command
	#system(ffmpeg_command)

	# Running the foreground extraction algorithm
	algo_path = "C:/Development/Algo/v-13-12-01/UniformMattingCA.exe"
	mask_path = "C:/Development/Algo/v-13-12-01/mask-m.bmp"
	first_image_path = images_fodler + "Image-0001.jpg"
	output_path = destination_folder + "Foreground-" + folder + ".avi"
	algo_command = algo_path + ' "' + mask_path + '" "' + first_image_path + '" "' + output_path + '"'
	puts algo_command 
	#system(algo_command)

	# Converting the large avi file to a small mp4 file
	mp4_path = output_path.chomp(File.extname(output_path)) + ".mp4"
	puts mp4_path
	convert_command = ffmpeg_path + ' -i "' + output_path + '" -vcodec mpeg4 -b:v 1200k "' + mp4_path + '"'
	puts convert_command
	#system(convert_command)

	# Doing everything on a thread
	Thread.new {
		system(ffmpeg_command)
		system(algo_command)
		system(convert_command)
		FileUtils.remove_file(output_path)
		FileUtils.remove_dir(images_fodler)
	}

	"Wait a minute..."
	# Deleting the big avi file
	#FileUtils.remove_file(output_path)

	# Deleting the images directory
	#FileUtils.remove_dir(images_fodler)

end


