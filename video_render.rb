#encoding: utf-8
require 'sinatra'
require 'mongo'
require 'uri'
require 'json'
require 'fileutils'
require 'open-uri'
require 'aws-sdk'
require 'houston'
require 'mini_exiftool'
require 'gcm'

configure do
	# Global configuration (regardless of the environment)

	# Setting folders param
	set :aeProjectsFolder, "C:/Users/Administrator/Documents/AE Projects/"
	set :aerenderPath, "C:/Program Files/Adobe/Adobe After Effects CC/Support Files/aerender.exe"
	set :outputFolder, "Z:/Output/" # "C:/Users/Administrator/Documents/AE Output/"
	set :ffmpeg_path, "C:/Development/FFmpeg/bin/ffmpeg.exe"
	set :algo_path, "C:/Development/Algo/v-14-07-10/UniformMattingCA.exe"
	set :remakes_folder, "Z:/Remakes/" # "C:/Users/Administrator/Documents/Remakes/"
	set :roi_path, "C:/Development/Algo/Full.ebox"
	set :cdn_path, "http://d293iqusjtyr94.cloudfront.net/"
	set :s3_bucket_path, "https://homageapp.s3.amazonaws.com/"
	set :rendering_semaphore, Mutex.new
	set :exiftool_semaphore, Mutex.new
	set :params_path, "C:/Development/Algo/params.xml"
	set :cdn_folder, "Z:/CDN/"

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	# Google Cloud Messaging - Android Push Notification
	set :gcm, GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")

	# Logger

  	# Logging the routes both to console (STDOUT/STDERR) and filw
	#logger_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
 	#logger_file.sync = true
  	#use Rack::CommonLogger, logger_file

  	# Logging everything to file (instead of console)
  	log_file = File.new("sinatra.log", "a+")
  	log_file.sync = true
 	$stdout.reopen(log_file)
  	$stderr.reopen(log_file)
end

configure :production do
	# Production DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod")
	set :db, db_connection.db()

	# Push notification certificate
	APN = Houston::Client.production
	APN.certificate = File.read(File.expand_path("../certificates/homage_push_notification_prod.pem", __FILE__))
	APN.passphrase = "homage"

	set :share_link_prefix, "http://play.homage.it/"

	set :logging, Logger::INFO
end

configure :test do
	# Test DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	# Push notification certificate
	# APN = Houston::Client.development
	# APN.certificate = File.read(File.expand_path("../certificates/homage_push_notification_dev.pem", __FILE__))
	APN = Houston::Client.production
	APN.certificate = File.read(File.expand_path("../certificates/homage_push_notification_prod.pem", __FILE__))
	APN.passphrase = "homage"


	set :share_link_prefix, "http://homage-server-app-test-nuskncpdiu.elasticbeanstalk.com/play/"

	set :logging, Logger::DEBUG
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

module PushNotifications
	MovieReady = 0
	MovieTimout = 1
end


# Get all stories
get '/stories' do
	stories_collection = settings.db.collection("Stories")
	stories_docs = stories_collection.find({active: true}, {fields: {after_effects: 0}}).sort({order_id: 1})

	stories_json_array = Array.new
	for story_doc in stories_docs do
		stories_json_array.push(story_doc.to_json)
	end

	logger.info "Returning " + stories_json_array.count.to_s + " stories"

	stories = "[" + stories_json_array.join(",") + "]"
	# stories = JSON[stories_docs]
end

get '/test/user' do
	form = '<form action="/user" method="post" enctype="multipart/form-data"> e-mail: <input type="text" name="user_id"> <input type="submit" value="Create User"> </form>'
	erb form
end

post '/user' do
	# input
	user_id_email = params[:user_id]
	
	logger.info "Creating a new user with email <" + user_id_email + ">"

	users = settings.db.collection("Users")

	# Check if this email already exists
	user = users.find_one({_id: user_id_email})

	if user then
		# user if this email already exists
		logger.info "User already exists with id <" + user_id_email + ">. Returnig the existing user"
	else
		# Creating a new user
		user = {_id: user_id_email, is_public: true};
		user_id = users.save(user)
		logger.info "New user saved in the DB with user_id <" + user_id.to_s + ">"
	end

	# Returning the user
	result = user.to_json
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

	remake = {_id: remake_id, story_id: story_id, user_id: user_id, created_at: Time.now ,status: RemakeStatus::New, 
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
	remakes_docs = settings.db.collection("Remakes").find({user_id: user_id, status: {"$in" => [RemakeStatus::InProgress, RemakeStatus::Rendering, RemakeStatus::Done, RemakeStatus::Timeout]}});

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

def upload_to_s3 (file_path, s3_key, acl, content_type=nil)

	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']
	s3_object = bucket.objects[s3_key]

	logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
	file = File.new(file_path)
	s3_object.write(file, {:acl => acl, :content_type => content_type})
	file.close
	logger.info "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s

	return s3_object

end

def download_from_s3 (s3_key, local_path)

	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']

	logger.info "Downloading file from S3 with key " + s3_key
	s3_object = bucket.objects[s3_key]

	File.open(local_path, 'wb') do |file|
  		s3_object.read do |chunk|
    		file.write(chunk)
    	end
    	file.close
    end

  	logger.info "File downloaded successfully to: " + local_path
end

def download_from_url (url, local_path)
	File.open(local_path, 'wb') do |file|
		file << open(url).read
    end	
end

get '/test/url/download' do
	url = 'http://s3.amazonaws.com/homageapp/Contours/360/american+shot+360.ctr'
	#local_path = settings.remakes_folder + File.basename(s3_key)
	local_path = "/Users/tomer/Desktop/Delete/Remakes/" + "test.txt" #File.basename(url)

	puts local_path

	download_from_url url, local_path
end


def delete_from_s3 (s3_key_prefix)
	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']

	puts "Deleting object from S3 with prefix " + s3_key_prefix
	bucket.objects.with_prefix(s3_key_prefix).delete_all
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
	take_id = params[:take_id]

	new_footage remake_id, scene_id, take_id

	# Returning the remake after the DB update
	remake = settings.db.collection("Remakes").find_one(remake_id).to_json
end

def is_latest_take(remake_id, scene_id, take_id)
	remake = settings.db.collection("Remakes").find_one(remake_id)
	db_take_id = remake["footages"][scene_id - 1]["take_id"]
	if db_take_id then
		if db_take_id == take_id then
			return true
		else
			logger.info "Not the latest take for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">. DB take_id <" + db_take_id + "> while given take_id <" + take_id + ">"
			return false
		end
	else
		# No take_id then assuiming this is the latest one
		return true
	end
end

get '/test/latest/take' do
	remake_id = BSON::ObjectId.from_string("534e39bfbb1945affc000002")
	remake_id_no_take_id = BSON::ObjectId.from_string("534e39c1bb1945affc000004")
	scene_id = 1
	correct_take_id = "vbf3332s"
	wrong_take_id = "12345ddd"

	if is_latest_take(remake_id, scene_id, correct_take_id) then
		logger.info "Good Correct"
	else
		logger.info "Bad Correct"
	end

	if is_latest_take(remake_id, scene_id, wrong_take_id) then
		logger.info "Bad Wrong"
	else
		logger.info "Good Wrong"
	end

	if is_latest_take(remake_id_no_take_id, scene_id, correct_take_id) then
		logger.info "Good no take id"
	else
		logger.info "Bad no take id"
	end
	
end

def new_footage (remake_id, scene_id, take_id)
	logger.info "New footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s + " with take_id " + take_id

	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")

	if is_latest_take(remake_id, scene_id, take_id) then

		# Updating the status of this remake to in progress
		remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::InProgress}})

		# Updating the status of this footage to uploaded
		result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Uploaded}})
		#logger.debug "DB Result: " + result.to_s
		logger.info "Footage status updated to Uploaded (1) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

		Thread.new{
			# Running the foreground extraction algorithm
			foreground_extraction remake_id, scene_id, take_id
		}
	else
		# if this is not the latest take, ignoring the call
		logger.info "Ignoring the request since this is not the latest take for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	end
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
	upload_to_s3 video.path, s3_key, :private

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
	ffmpeg_command = settings.ffmpeg_path + ' -ss ' + time.to_s + ' -i "' + video_path + '" -frames:v 1 -vf crop=640:360 -y ' + '"' + thumbnail_path + '"'
	logger.info "*** Extract Thumbnail from Video *** \n" + ffmpeg_command
	system(ffmpeg_command)
end

def is_upside_down (video_metadata)
	if video_metadata.Rotation == 180 then
		return true
	else
		return false
	end	
end

def has_audio_channel (video_metadata)
	if video_metadata.AudioChannels then
		return true
	else
		return false
	end
end

def get_frame_rate (video_metadata)
	return video_metadata.VideoFrameRate.round.to_s
end

def get_resolution (video_metadata)
	return video_metadata.ImageHeight
end


def handle_orientation (video_path)
	video_metadata = MiniExiftool.new(video_path)
	if video_metadata.Rotation == 180 then
		# need to rotate the video
		# ffmpeg -i input.mp4 -metadata:s:v rotate="0" -vf "hflip,vflip" -c:v libx264 -crf 23 -acodec copy output.mp4
		rotated_video_path = File.dirname(video_path) + "/" + File.basename(video_path, ".*") + "-rotated" + File.extname(video_path)
		rotate_command = settings.ffmpeg_path + ' -i "' + video_path + '" -metadata:s:v rotate="0" -vf "hflip,vflip" -c:v libx264 -crf 23 -acodec copy -y ' + rotated_video_path
		logger.info "*** Rotating Video *** \n" + rotate_command
		system(rotate_command)
		return rotated_video_path
	else
		return video_path
	end
end

get '/test/orientation' do
	video_path = "/Users/tomer/Desktop/Delete/orientation/IMG_0570.MOV"
	rotated_video_path = handle_orientation(video_path)
	logger.info rotated_video_path
end

def foreground_extraction (remake_id, scene_id, take_id)
	# Fetching the remake for this footage
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	logger.info "Running foreground extraction for scene " + scene_id.to_s + " for remkae " + remake_id.to_s + " with take_id " + take_id

	# Creating a new directory for the foreground extraction
	foreground_folder = settings.remakes_folder + remake_id.to_s + "_scene_" + scene_id.to_s + "/"
	while File.directory?(foreground_folder) do
		logger.debug "Waiting for algo on same scene to complete"
		sleep(1)
	end
	logger.info "Creating temp folder: " + foreground_folder.to_s
	FileUtils.mkdir foreground_folder

	# Updating the status of this footage to Processing
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Processing}})
	logger.info "Footage status updated to Processing (2) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

	# Downloading the raw video from s3
	raw_video_s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	raw_video_file_name = File.basename(raw_video_s3_key)
	raw_video_file_path = foreground_folder + raw_video_file_name	
	download_from_s3 raw_video_s3_key, raw_video_file_path

	# Checking if foreground extraction is needed
	if story["scenes"][scene_id - 1]["silhouette"] or story["scenes"][scene_id - 1]["silhouettes"] then
		#raw_video_file_path = handle_orientation(raw_video_file_path)

		# Getting metadata information for this video (protecting it with a semaphore)
		logger.info "beofre exiftool for " + raw_video_file_path
		video_metadata = nil
		settings.exiftool_semaphore.synchronize{
			video_metadata = MiniExiftool.new(raw_video_file_path)
		}
		logger.info "after exiftool for " + raw_video_file_path

		# Getting the frame rate for this video
		frame_rate = get_frame_rate(video_metadata)

		# Getting the resolution (height) for this video
		resolution = get_resolution(video_metadata)

		# resizing/croping the video if needed
		if resolution == 720 then
			# resizing to 360
			resized_video_path = foreground_folder + File.basename(raw_video_file_path, ".*" ) + "-resized" + ".mp4"
			resize_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -vf scale=640:360 -y "' + resized_video_path + '"'
			logger.info "*** Resize video from 720 to 360 *** " + resize_command
			system(resize_command)
			raw_video_file_path = resized_video_path
		elsif resolution == 480 then
			# cropping to 360
			cropped_video_path = foreground_folder + File.basename(raw_video_file_path, ".*" ) + "-cropped" + ".mp4"
			crop_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -vf crop=640:360:0:60 -y "' + cropped_video_path + '"'
			logger.info "*** Crop video from 480 to 360 *** " + crop_command
			system(crop_command)
			raw_video_file_path = cropped_video_path
		end

		# images from the video
		images_fodler = foreground_folder + "Images/"
		ffmpeg_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -r ' + frame_rate + ' -q:v 1 "' + images_fodler + 'Image-%4d.jpg"'
		logger.info "*** Video to images *** \n" + ffmpeg_command
		unless File.directory?(images_fodler)
			FileUtils.mkdir images_fodler
		end
		system(ffmpeg_command)
		logger.debug "video to image ended"

		# Assigning the flip switch if this video is upside down
		flip_switch = ""
		if is_upside_down(video_metadata) then
			flip_switch = "-Flip"
		end

		# foreground extraction algorithm
		if remake["resolution"] then
			contour_path = story["scenes"][scene_id - 1]["contours"][remake["resolution"]]["contour"]
		else
			contour_path = story["scenes"][scene_id - 1]["contour"]
		end
		first_image_path = images_fodler + "Image-0001.jpg"
		output_path = foreground_folder + File.basename(raw_video_file_path, ".*" ) + "-Foreground" + ".avi"
		logger.debug "before algo"
		algo_command = settings.algo_path + ' -CA "' + settings.params_path + '" "' + contour_path + '" ' + flip_switch + ' "' + first_image_path + '" -avic -r' + frame_rate + ' -mp4 "' + output_path + '"'
		logger.info "*** Running Algo *** \n" + algo_command 
		system(algo_command)

		# Converting the large avi file to a small mp4 file
		mp4_path = output_path.chomp(File.extname(output_path)) + ".mp4"
		convert_command = settings.ffmpeg_path + ' -i "' + output_path + '" -vcodec mpeg4 -b:v 1200k -y "' + mp4_path + '"'
		puts "*** avi to mp4 *** \n" + convert_command
		system(convert_command)

		# Adding audio to video (if the raw video has an audio channel)
		if has_audio_channel(video_metadata) then
			output_with_audio_path = foreground_folder + File.basename(raw_video_file_path, ".*" ) + "-Foreground_Audio" + ".mp4"
			add_audio_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -i "' + mp4_path + '" -c copy -map 0:1 -map 1:0 -y "' + output_with_audio_path + '"'
			logger.info "*** audio to video *** \n" + add_audio_command
			system(add_audio_command)
		else
			output_with_audio_path = mp4_path
		end
	else
		# If no foreground extraction is required then uploading the same file that was downloaded
		output_with_audio_path = raw_video_file_path
	end

	# upload to s3
	processed_video_s3_key = remake["footages"][scene_id - 1]["processed_video_s3_key"]
	upload_to_s3 output_with_audio_path, processed_video_s3_key, :private

	# Updating the status of this footage to Ready
	if is_latest_take(remake_id, scene_id, take_id) then
		result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Ready}})
		logger.info "Footage status updated to Ready (3) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	else
		logger.info "not updating the DB to status ready since this is not the latest take for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	end
	#logger.debug "DB Result: " + result.to_s

	# Deleting the folder after everything was updated successfully
	logger.info "Deleting temp folder: " + foreground_folder.to_s
	FileUtils.remove_dir(foreground_folder)
end

# The OLD foreground that creates a sequence of png images, and then creates a video with alpha from it
def foreground_extraction_png (remake_id, scene_id)
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
	ffmpeg_command = settings.ffmpeg_path + ' -i "' + raw_video_file_path + '" -r 25 -q:v 1 "' + images_fodler + 'Image-%4d.jpg"'
	logger.info "*** Video to images *** \n" + ffmpeg_command
	FileUtils.mkdir images_fodler
	system(ffmpeg_command)

	# foreground extraction algorithm
	if remake["resolution"] then
		contour_path = story["scenes"][scene_id - 1]["contours"][remake["resolution"]]["contour"]
	else
		contour_path = story["scenes"][scene_id - 1]["contour"]
	end
	#roi_path = story["scenes"][scene_id - 1]["ebox"]
	roi_path = settings.roi_path
	first_image_path = images_fodler + "Image-0001.jpg"
	output_folder = File.dirname(raw_video_file_path) + "/" + File.basename(raw_video_file_path, ".*") + "_Foreground/"
	output_path = output_folder + "Output"
	algo_command = settings.algo_path + ' -CA "' + contour_path + '" "' + roi_path + '" "' + first_image_path + '" -png "' + output_path + '"'
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
	upload_to_s3 output_with_audio_path, processed_video_s3_key, :private

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

def update_story_remakes_count(story_id)
	remakes = settings.db.collection("Remakes")
	stories = settings.db.collection("Stories")

	story = stories.find_one(story_id)

	# Getting the number of remakes for this story
	story_remakes = remakes.count({query: {story_id: story_id, status: RemakeStatus::Done}})
	if story["story_480"] then
		story_480_remakes = remakes.count({query: {story_id: story["story_480"], status: RemakeStatus::Done}})
		story_remakes += story_480_remakes
	end

	stories.update({_id: story_id}, {"$set" => {"remakes_num" => story_remakes}})
	logger.info "Updated story id <" + story_id.to_s + "> number of remakes to " + story_remakes.to_s
end

get '/test/update/remakes/:story_id' do
	story_id = BSON::ObjectId.from_string(params[:story_id])

	update_story_remakes_count story_id
end

def render_video (remake_id)
	# Fetching the remake and story for this remake
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	logger.info "Starting the rendering of remake " + remake_id.to_s

	if remake["resolution"] then
		story_folder = story["after_effects"][remake["resolution"]]["folder"]
		story_project = story["after_effects"][remake["resolution"]]["project"]
	else
		story_folder = story["after_effects"]["folder"]
		story_project = story["after_effects"]["project"]
	end

	# Updating the DB that the process has started
	#remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Rendering}})

	# copying all videos to after project (downloading them from s3)
	for scene in story["after_effects"]["scenes"] do
		processed_video_s3_key = remake["footages"][scene["id"] - 1]["processed_video_s3_key"]
		destination = settings.aeProjectsFolder + story_folder + "/(Footage)/" + scene["file"]
		download_from_s3 processed_video_s3_key, destination
	end

	projectPath = settings.aeProjectsFolder + story_folder + "/" + story_project
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
	s3_object_video = upload_to_s3 output_path, video_s3_key, :public_read, 'video/mp4'
	s3_object_thumbnail = upload_to_s3 thumbnail_path, thumbnail_s3_key, :public_read

	share_link = settings.share_link_prefix + remake_id.to_s
	video_cdn_url = s3_object_video.public_url.to_s.sub(settings.s3_bucket_path, settings.cdn_path)
	thumbnail_cdn_url = s3_object_thumbnail.public_url.to_s.sub(settings.s3_bucket_path, settings.cdn_path)
	render_end = Time.now
	if remake["render_start"] then
		render_duration = render_end - remake["render_start"]
	end

	# Updating the DB that the movie is ready
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Done, video: video_cdn_url, thumbnail: thumbnail_cdn_url, share_link: share_link, render_end: render_end, render_duration: render_duration, grade:-1}})
	logger.info "Updating DB: remake " + remake_id.to_s + " with status Done and url to video: " + video_cdn_url

	send_movie_ready_push_notification(story, remake)

	cdn_local_path = settings.cdn_folder + output_file_name
	logger.info "downloading the just created video to update CDN cache"
	download_from_url(video_cdn_url, cdn_local_path)
	logger.info "Now deleting the file that was downloaded for cache"
	FileUtils.remove_file(cdn_local_path)

	update_story_remakes_count(remake["story_id"])
end

def send_movie_ready_push_notification(story, remake)
	user_id = remake["user_id"]
	alert = "Your " + story["name"] + " movie is ready!"
	custom_data = {type: PushNotifications::MovieReady, remake_id: remake["_id"].to_s, story_id: story["_id"].to_s, title:"Movie Ready!"}

	send_push_notification_to_user(user_id, alert, custom_data)
end

def send_movie_timeout_push_notification(remake)
	user_id = remake["user_id"]
	alert = "Failed to create your movie, open the application and try again"
	custom_data = {type: PushNotifications::MovieTimout, remake_id: remake["_id"].to_s, story_id: remake["story_id"].to_s, title:"Movie Creation Failed"}

	send_push_notification_to_user(user_id, alert, custom_data)
end

def send_push_notification_to_user(user_id, alert, custom_data)
	logger.debug "send_push_notification_to_user: " + user_id.to_s + "; " + alert + "; " + custom_data.to_s

	# If this is the old user id (not an ObjectId, then returning)
	if !BSON::ObjectId.legal?(user_id.to_s) then
		logger.debug "not legal"
		return
	end

	token_used = Set.new

	# Getting the user of this remake and pushing a notification to all his devices
	users = settings.db.collection("Users")
	user = users.find_one(user_id)
	for device in user["devices"] do
		if device.has_key?("push_token") then
			token = device["push_token"]
			if !token_used.include?(token) then
				send_push_notification(token, alert, custom_data)
				token_used.add(token)
			end
		elsif device.has_key?("android_push_token") then
			token = device["android_push_token"]
			if !token_used.include?(token) then
				send_android_push_notification(token, alert, custom_data)
				token_used.add(token)
			end			
		end
	end
end

def send_push_notification(device_token, alert, custom_data)
	logger.info "Sending push notification to device token: " + device_token.to_s + " with alert: " + alert + " with custom_data: " + custom_data.to_s
	notification = Houston::Notification.new(device: device_token)
	notification.alert = alert
	notification.custom_data = custom_data
	notification.sound = "default"
	APN.push(notification)	
end

get '/test/android/push' do
	token = "APA91bE4MZmyhKWNiYyecfa8r0cHzai6KGv_LJTz59mdWlCFUQ_Y6fIu9U3V0myH7yfKWL3qr_ru8f4xkThOVsTtbbaSFwiZpBryF6zy9At4h3Q7ySQQEbKQMfH1PXYzJwm_HykxTltsHZDaykGNZj5c6Fv3TFKtyw"
	data = {type: 0, title: "Video is Ready!", remake_id: "5415863ab8fef16bc5000012", story_id: "53ce9bc405f0f6e8f2000655"}
	message = "Your Street Fighter Video is Ready!"
	send_android_push_notification(token, message, data)
end

def send_android_push_notification(device_token, alert, custom_data)
	logger.info "Sending android push notification to device token: " + device_token.to_s + " with alert: " + alert + " with custom_data: " + custom_data.to_s
	tokens = [device_token]
	custom_data[:text] = alert
	data = {data: custom_data}
	logger.debug "Sending tokens = " + tokens.to_s + "; data = " + data.to_s
	push_response = settings.gcm.send(tokens, data)
	logger.debug push_response
end


get '/test/mutex' do
	thread_id = BSON::ObjectId.new

	Thread.new{
		puts "New thread: " + thread_id.to_s

		settings.rendering_semaphore.synchronize{
			puts "Thread " + thread_id.to_s + "Going to Sleep..."
			sleep 8
			puts "Thread " + thread_id.to_s + "Good Morning!"			
		}
	}
end

post '/render' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	# Updating the DB that the process has started
	remakes = settings.db.collection("Remakes")
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Rendering}})

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
			# Synchronizing the actual rendering (because we cannot have more than 1 rendering in parallel)
			if settings.rendering_semaphore.locked? then
				logger.info "Rendering for remake " + remake_id.to_s + " waiting for other threads to finish rendering"
			else
				logger.debug "Rendering is going to start for remake " + remake_id.to_s
			end	
			settings.rendering_semaphore.synchronize{
				render_video remake_id
			}
		else
			logger.warn "Timeout on the rendering of remake <" + remake_id.to_s + "> - updating DB"
			remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Timeout}})
			logger.info "DB update result: " + result.to_s
			remake = remakes.find_one(remake_id)
			send_movie_timeout_push_notification(remake)
		end
	}

	remake = remakes.find_one(remake_id).to_json
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

	s3_key = 'Remakes/539ead2470b35d5c43000026/raw_scene_1.mov'
	#local_path = settings.remakes_folder + File.basename(s3_key)
	local_path = "/Users/tomer/Desktop/Delete/Remakes" + File.basename(s3_key)

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

	s3_object = upload_to_s3 file.path, s3_key, :private, 'video/mp4'

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
	video_path = "/Users/tomer/Desktop/Delete/orientation/IMG_0570-rotated.MOV"
	time = 0.5
	thumbnail_path = "/Users/tomer/Desktop/Delete/orientation/IMG_0570-tumbnail.jpg"

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

get '/play/intro' do
	headers \
		"X-Frame-Options"   => "ALLOW-FROM http://play.homage.it/"

	erb :intro
end

#get '/play/DemoDay' do
get %r{^/play/demoday/?$}i do
	headers \
		"X-Frame-Options"   => "ALLOW-FROM http://play.homage.it/"

	@remakes = settings.db.collection("Remakes").find({demo_day: true})
	erb :demoday
end 

get '/play/:remake_id' do
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	remakes = settings.db.collection("Remakes")
	@remake = remakes.find_one(remake_id)

	stories = settings.db.collection("Stories")
	@story = stories.find_one(@remake["story_id"])

	headers \
		"X-Frame-Options"   => "ALLOW-FROM http://play.homage.it/"

	erb :video
end

get '/test/env' do
	logger.info "Environment: " + ENV['RACK_ENV'].to_s
end

get '/health/check' do
end

get '/test/push' do
	user_id = BSON::ObjectId.from_string("53306186f52d5c6a14000006")
	alert = "How many notifications?"
	custom_data = {type: 0, remake_id: "kjfdkjf333kj3kj3kj3"}
	
	send_push_notification_to_user(user_id, alert, custom_data)

	"done"
end
