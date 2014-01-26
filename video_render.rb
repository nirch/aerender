#encoding: utf-8
require 'sinatra'
require 'mongo'
require 'uri'
require 'json'
require 'fileutils'
require 'open-uri'
require 'aws-sdk'

configure do
	# Setting db connection param
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	# Setting folders param
	set :aeProjectsFolder, "C:/Users/Administrator/Documents/AE Projects/"
	set :aerenderPath, "C:/Program Files/Adobe/Adobe After Effects CS6/Support Files/aerender.exe"
	set :outputFolder, "C:/Users/Administrator/Documents/AE Output/"
	set :ffmpeg_path, "C:/Development/ffmpeg/ffmpeg-20131202-git-e3d7a39-win64-static/bin/ffmpeg.exe"
	set :algo_path, "C:/Development/Algo/v-14-01-19/UniformMattingCA.exe"
	set :remakes_folder, "C:/Users/Administrator/Documents/Remakes/"

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	# Logger

  	# Logging the routes both to console (STDOUT/STDERR) and filw
	logger_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
 	logger_file.sync = true
  	use Rack::CommonLogger, logger_file
 	set :logging, Logger::DEBUG

  	# Logging everything to file (instead of console)
 	#$stdout.reopen(log_file)
  	#$stderr.reopen(log_file)
end

# Logging logger to file (instead of console)
#before do
#	logger.level
#	env['rack.logger'] = Logger.new('sinatra.log', 'weekly')
#end

module RemakeStatus
  New = 0
  InProgress = 1
  Rendering = 2
  Done = 3
  Timeout = 4
  Deleted = 5
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

	logger.info "Returning " + stories_json_array.count.to_s + " stories"

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
	
	logger.info "Creating a new remake for story <" + story["name"] + "> for user <" + user_id + "> with remake_id <" + remake_id.to_s + ">"

	s3_folder = "Remakes" + "/" + remake_id.to_s + "/"
	s3_video = s3_folder + story["name"] + "_" + remake_id.to_s + ".mp4"
	s3_thumbnail = s3_folder + story["name"] + "_" + remake_id.to_s + ".jpg"

	remake = {_id: remake_id, story_id: story_id, user_id: user_id, status: RemakeStatus::New, 
		thumbnail: story["thumbnail"], video_s3_key: s3_video, thumbnail_s3_key: s3_thumbnail}

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

	logger.info "New remake saved in the DB with remake id " + remake_objectId.to_s

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

	logger.info "Deleting (marking as deleted) remake " + remake_id.to_s

	# Updating the DB that this remake is marked as deleted
	remakes = settings.db.collection("Remakes")
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Deleted}})
	#settings.db.collection("Remakes").remove({_id: remake_id})
	
	# Returning the updated remake
	remake = remakes.find_one(remake_id).to_json
end

# Returns a given remake id
get '/remake/:remake_id' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	logger.info "Getting remake with id " + remake_id.to_s

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

	logger.info "Getting remakes for user " + user_id

	# Returning all the remakes of the given user and those with status inProgress, Rendering, Done and Timeout
	remakes_docs = settings.db.collection("Remakes").find({user_id: "nir@homage.it", status: {"$in" => [RemakeStatus::InProgress, RemakeStatus::Rendering, RemakeStatus::Done, RemakeStatus::Timeout]}});

	remakes_json_array = Array.new
	for remake_doc in remakes_docs do
		remakes_json_array.push(remake_doc.to_json)
	end

	logger.info "Returning " + remakes_json_array.count.to_s + " remakes"

	remakes = "[" + remakes_json_array.join(",") + "]"
end

# Returns all the remakes of a given story
get '/remakes/story/:story_id' do
	# input
	story_id = BSON::ObjectId.from_string(params[:story_id])

	logger.info "Getting remakes for story " + story_id.to_s

	remakes_docs = settings.db.collection("Remakes").find({story_id: story_id, status: RemakeStatus::Done});

	remakes_json_array = Array.new
	for remake_doc in remakes_docs do
		remakes_json_array.push(remake_doc.to_json)
	end

	logger.info "Returning " + remakes_json_array.count.to_s + " remakes for story " + story_id.to_s

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

get '/test/text' do
	form = '<form action="/text" method="post" enctype="multipart/form-data"> Remake ID: <input type="text" name="remake_id"> Text ID: <input type="text" name="text_id"> Text: <input type="text" name="text"> <input type="submit" value="Text!"> </form>'
	erb form
end

post '/text' do
	#input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	text_id = params[:text_id].to_i	
	text = params[:text]

	puts "Text <" + text + "> applied for remake <" + remake_id.to_s + "> text_id <" + text_id.to_s + ">"

	remakes = settings.db.collection("Remakes")
	result = remakes.update({_id: remake_id, "texts.text_id" => text_id}, {"$set" => {"texts.$.text" => text}})

	# Returning the remake after the DB update
	remake = remakes.find_one(remake_id).to_json
end

# Post a new footage (params are: uploaded file, remake id, scene id)
post '/footage' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i

	new_footage remake_id, scene_id

	# Returning the remake after the DB update
	remake = settings.db.collection("Remakes").find_one(remake_id).to_json
end

def new_footage (remake_id, scene_id)
	logger.info "New footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s

	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")

	# Updating the status of this remake to in progress
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::InProgress}})

	# Updating the status of this footage to uploaded
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Uploaded}})
	#logger.debug "DB Result: " + result.to_s
	logger.info "Footage status updated to Uploaded (1) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

	Thread.new{
		# Running the foreground extraction algorithm
		#foreground_extraction remake_id, scene_id
	}
end

# Post a new footage (params are: uploaded file, remake id, scene id)
post '/footage_prototype' do
	# input
	source = params[:file][:tempfile]
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i

	new_footage_prototype source, remake_id, scene_id
end

def new_footage_prototype (video, remake_id, scene_id)
	logger.info "New footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s

	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)

	# Uploading to S3
	s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	upload_to_s3 video, s3_key, :private

	# Updating the status of this remake to in progress
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::InProgress}})

	# Updating the status of this footage to uploaded
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Uploaded}})
	logger.info "Footage status updated to Uploaded (1) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	#logger.debug "DB Result: " + result.to_s

	Thread.new{
		# Running the foreground extraction algorithm
		foreground_extraction remake_id, scene_id
	}
end

def extract_thumbnail (video_path, time, thumbnail_path)
	ffmpeg_command = settings.ffmpeg_path + ' -ss ' + time.to_s + ' -i "' + video_path + '" -frames:v 1 -s 640x360 ' + '"' + thumbnail_path + '"'
	logger.info "*** Extract Thumbnail from Video *** \n" + ffmpeg_command
	system(ffmpeg_command)
end

def foreground_extraction (remake_id, scene_id)
	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	logger.info "Running foreground extraction for scene " + scene_id.to_s + " for remkae " + remake_id.to_s

	# Updating the status of this footage to Processing
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Processing}})
	logger.info "Footage status updated to Processing (2) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	#logger.debug "DB Result: " + result.to_s

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
	logger.info "*** Video to images *** \n" + ffmpeg_command
	FileUtils.mkdir images_fodler
	system(ffmpeg_command)

	# foreground extraction algorithm
	contour_path = story["scenes"][scene_id - 1]["contour"]
	roi_path = story["scenes"][scene_id - 1]["ebox"]
	first_image_path = images_fodler + "Image-0001.jpg"
	output_folder = File.dirname(raw_video_file_path) + "/" + File.basename(raw_video_file_path, ".*") + "_Foreground/"
	output_path = output_folder + "Output"
	algo_command = settings.algo_path + ' "' + contour_path + '" "' + roi_path + '" "' + first_image_path + '" -png "' + output_path + '"'
	logger.info "*** Running Algo *** \n" + algo_command 
	FileUtils.mkdir output_folder
	system(algo_command)

	# pngs to video
	output_file_name = "foreground_" + "scene_" + scene_id.to_s + ".mov"
	output_video_path = File.dirname(raw_video_file_path) + "/" + output_file_name
	png_convert_command = settings.ffmpeg_path + ' -i "' + output_path.chomp(File.extname(output_path)) + '-%2d.png"' + ' -vcodec png "' + output_video_path + '"'
	logger.info "*** png to video *** \n" + png_convert_command
	system(png_convert_command)

	# Adding audio to video
	output_with_audio_path = File.dirname(raw_video_file_path) + "/" + "audio_foreground_scene" + scene_id.to_s + ".mov"
	add_audio_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -i "' + output_video_path + '" -c copy -map 0:1 -map 1:0 "' + output_with_audio_path + '"'
	logger.info "*** audio to video *** \n" + add_audio_command
	system(add_audio_command)

	# upload to s3
	processed_video_s3_key = remake["footages"][scene_id - 1]["processed_video_s3_key"]
	upload_to_s3 File.new(output_with_audio_path), processed_video_s3_key, :private

	#remake["footages"][scene_id - 1][:processed] = output_with_audio_path

	# Updating the status of this footage to Ready
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Ready}})
	logger.info "Footage status updated to Ready (3) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	#logger.debug "DB Result: " + result.to_s

	# Deleting the folder after everything was updated successfully
	#FileUtils.remove_dir(foreground_folder)
end

def is_remake_ready (remake_id)
	remake = settings.db.collection("Remakes").find_one(remake_id)
	is_ready = true

	for footage in remake["footages"] do
		if footage["status"] != FootageStatus::Ready 
			is_ready = false;
		end
	end

	return is_ready
end

def render_video (remake_id)

	# Fetching the remake and story for this remake
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	logger.info "Starting the rendering of remake " + remake_id.to_s

	# Updating the DB that the process has started
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Rendering}})

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
	logger.info "aerender command line: #{aerenderCommandLine}"

	# Rendering the movie
	system(aerenderCommandLine)

	# Creating a thumbnail from the video
	thumbnail_path = File.dirname(output_path) + "/" + File.basename(output_path,".*") + ".jpg"
	thumbnail_rip_time = story["thumbnail_rip"]
	extract_thumbnail output_path, thumbnail_rip_time ,thumbnail_path

	video_s3_key = remake["video_s3_key"]
	thumbnail_s3_key = remake["thumbnail_s3_key"]

	# Uploading the movie and thumbnail to S3
	s3_object_video = upload_to_s3 File.new(output_path), video_s3_key, :public_read
	s3_object_thumbnail = upload_to_s3 File.new(thumbnail_path), thumbnail_s3_key, :public_read

	# Updating the DB that the movie is ready
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Done, video: s3_object_video.public_url.to_s, thumbnail: s3_object_thumbnail.public_url.to_s}})
	logger.info "Updating DB: remake " + remake_id.to_s + " with status Done and url to video: " + s3_object_video.public_url.to_s
end

post '/render' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	Thread.new{
		# Waiting until this remake is ready for rendering (or there is a timout)
		is_ready = is_remake_ready remake_id 
		sleep_for = 900
		sleep_duration = 5
		while ! is_ready && sleep_for > 0 do
			logger.info "Waiting for remake " + remake_id.to_s + " to be ready"
			sleep sleep_duration
			sleep_for -= sleep_duration
			is_ready = is_remake_ready remake_id
		end

		if is_ready then
			render_video remake_id
		else
			logger.warn "Timeout on the rendering of remake <" + remake_id.to_s + "> - updating DB"
			remakes = settings.db.collection("Remakes")
			remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Timeout}})
			logger.debug "DB update result: " + result.to_s
		end
	}

	remake = settings.db.collection("Remakes").find_one(remake_id).to_json
end

get '/test/remake/ready/wait/:remake_id' do

	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	
	Thread.new{
		sleep_for = 30
		sleep_duration = 3
		is_ready = is_remake_ready remake_id 

		while ! is_ready && sleep_for > 0 do
			puts "Going to sleep..."
			sleep sleep_duration
			sleep_for -= sleep_duration
			is_ready = is_remake_ready remake_id 		
		end

		if is_ready then
			puts "ready!!!"
		else
			puts "was never ready!!!"
		end

		puts "sleep left = " + sleep_for.to_s
	}
end

get '/test/logger' do
	logger.debug "Log debug test"
	logger.info "Log info test"
	logger.warn "Log warn test"
	logger.error "Log error test"
	logger.fatal "Log fatal test"
end

get '/test/remake/delete' do
	# input
	remake_id = BSON::ObjectId.from_string("52e175f3db2545022400000e")


	logger.info "Deleting (marking as deleted) remake " + remake_id.to_s

	# Updating the DB that this remake is marked as deleted
	remakes = settings.db.collection("Remakes")
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Deleted}})
	remake = remakes.find_one(remake_id)
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

get '/test/footage_prototype' do
	form = '<form action="/test/footage_prototype" method="post" enctype="multipart/form-data"> <input type="file" accept="video/*" name="file"> Remake ID: <input type="text" name="remake_id"> Scene ID: <input type="text" name="scene_id"> <input type="submit" value="Upload!"> </form>'
	erb form
end


get '/test/render' do
	form = '<form action="/render" method="post" enctype="multipart/form-data"> Remake ID: <input type="text" name="remake_id"> <input type="submit" value="Render!"> </form>'
	erb form
end

get '/test/foreground' do
	form = '<form action="/test/foreground" method="post" enctype="multipart/form-data"> Remake ID: <input type="text" name="remake_id"> Scene ID: <input type="text" name="scene_id"> <input type="submit" value="Upload!"> </form>'
	erb form
end


post '/test/foreground' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i

	Thread.new{
		foreground_extraction remake_id, scene_id
	}

end

get '/test/thumbnail' do
	video_path = "C:/Users/Administrator/Documents/AE Output/Test_52d6a0dcdb254505fc000001.mp4"
	time = 1.2
	thumbnail_path = "C:/Users/Administrator/Documents/AE Output/Test__52d6a0dcdb254505fc000001_10.jpg"

	extract_thumbnail video_path, time, thumbnail_path
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

get '/download/:filename' do
	downloadPath = settings.outputFolder + params[:filename]
	puts "download file path: #{downloadPath}"
	send_file downloadPath #, :type => 'video/mp4', :disposition => 'inline'
end