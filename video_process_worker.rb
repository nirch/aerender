require 'sinatra'
require 'aws-sdk'
require 'mongo'
require_relative 'queue/AVUtils'

configure do
	# Global configuration (regardless of the environment)

	# Setting folders
	set :remakes_folder, "Z:/Remakes/" # "C:/Users/Administrator/Documents/Remakes/"

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	process_footage_url = "http://localhost:" + settings.port.to_s + "/process"
	set :process_footage_uri, URI.parse(process_footage_url)

	set :logging, Logger::DEBUG
end

configure :test do
	# Process Footage Queue
	process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueueTest"
    set :process_footage_queue, AWS::SQS.new.queues[process_footage_queue_url]

    # Test DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()
end	

module FootageStatus
  Open = 0
  Uploaded = 1
  Processing = 2
  Ready = 3
end

PARALLEL_PROCESS_NUM = 3

# Creating X threads that will poll the queue and process the message
for i in 1..PARALLEL_PROCESS_NUM do
	Thread.new do
		while true do
			begin
				settings.process_footage_queue.poll{ |msg|
					puts "message caught on ProcessFootageQueue. MessageId: " + msg.id + " MessageBody: " + msg.body

					# Creating an HTTP object and Request object (POST)
					http = Net::HTTP.new(settings.process_footage_uri.host, settings.process_footage_uri.port)
					request = Net::HTTP::Post.new(settings.process_footage_uri.request_uri)

					# Converting the message bpdy to a Hash and adding it to the request
					params = JSON.parse(msg.body)
					request.set_form_data(params)

					# Extending the timeout
					http.read_timeout = 150

					# Making the request
					response = http.request(request)
					#http.post('/process', "remake_id=2323, scene_id=2")
					#Net::HTTP.post_form(settings.process_footage_uri, params)

					if response.code != 200 then
						raise response.message["message"]
					end
				}
			rescue => error
				puts "rescued, exception happend, keeping the polling thread alive. Error: " + error.to_s
			end
		end
	end
end

post '/process' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i
	take_id = params[:take_id]

	logger.info "Process footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s + " with take_id " + take_id

	# Fetching the remake for this footage
	remake = settings.db.collection("Remakes")

	# Creating a new directory for the processing
	process_folder = settings.remakes_folder + remake_id.to_s + "_scene_" + scene_id.to_s + "_" + take_id + "/"

	# Returning an error if the directory exists
	if File.directory?(process_folder) then
		error_message = "process directory already exists for: " + process_folder
		logger.error error_message
		return [500, [{:message => error_message}.to_json]]
	end

	logger.info "Creating temp folder: " + process_folder.to_s
	FileUtils.mkdir process_folder

	# Updating the status of this footage to Processing
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Processing}})
	logger.info "Footage status updated to Processing (2) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

	# Downloading the raw video from s3
	raw_video_s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	raw_video_file_path = process_folder + File.basename(raw_video_s3_key)	
	download_from_s3 raw_video_s3_key, raw_video_file_path

	raw_video = AVUtils::Video.new(raw_video_file_path)

	# Checking if forgeound extraction is needed
	if story["scenes"][scene_id - 1]["silhouette"] or story["scenes"][scene_id - 1]["silhouettes"] then
		# Getting the contour
		if remake["resolution"] then
			contour_path = story["scenes"][scene_id - 1]["contours"][remake["resolution"]]["contour"]
		else
			contour_path = story["scenes"][scene_id - 1]["contour"]
		end

		# Processing the video
		processed_video = raw_video.process(contour_path)
	else
		logger.info "foreground extraction not needed for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

		# Resizing/Cropping the video to 360p (640x360) if needed
		if raw_video.resolution == "1280x720" then
			processed_video = raw_video.resize(640, 360)
		elsif video_to_process.resolution == "640x480" then
			processed_video = raw_video.crop(640, 360)
		else
			processed_video = raw_video
		end
	end

	# upload to s3
	processed_video_s3_key = remake["footages"][scene_id - 1]["processed_video_s3_key"]
	upload_to_s3 processed_video.path, processed_video_s3_key, :private

	# Updating the status of this footage to Ready
	if is_latest_take(remake_id, scene_id, take_id) then
		result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Ready}})
		logger.info "Footage status updated to Ready (3) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	else
		logger.info "not updating the DB to status ready since this is not the latest take for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	end

	# Deleting the folder after everything was updated successfully
	logger.info "Deleting temp folder: " + process_folder
	FileUtils.remove_dir(process_folder)


	# # Checking if this take is the latest take. If there is a newer take to this scene, ignoring this take
	# # TODO: this logic should move to the server?
	# if is_latest_take(remake, scene_id, take_id) then

	# 	# Updating the status of this remake to in progress / Again move this to the server?
	# 	remakes.update({_id: remake_id}, {"$set" => {status: 2}}) # RemakeStatus::InProgress

	# 	# Updating the status of this footage to uploaded / Again move this to server
	# 	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Uploaded}})

	# 	logger.info "Footage status updated to Uploaded (1) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

	# 	foreground_extraction remake_id, scene_id, take_id
	# else
	# 	# if this is not the latest take, ignoring the call
	# 	logger.info "Ignoring the request since this is not the latest take for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
	# end


	# logger.info "params = " + params.to_s
	# sleep 100
	# logger.info "successfully processed"
	# return "success"
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


def is_latest_take(remake, scene_id, take_id)
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
