require 'sinatra'
require 'aws-sdk'
require 'mongo'
require_relative 'video/AVUtils'
require_relative 'utils/push/Homage_Push'
require 'mail'
require 'open-uri'

configure do
	# Global configuration (regardless of the environment)
	set :server, 'webrick'

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	process_footage_url = "http://localhost:" + settings.port.to_s + "/process"
	set :process_footage_uri, URI.parse(process_footage_url)

	AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'
	AVUtils.algo_binary = 'C:/Development/Algo/v-14-11-10/UniformMattingCA.exe'
	AVUtils.algo_params = 'C:/Development/Algo/params.xml'

	# Using Amazon's SES for mail delivery
	Mail.defaults do
  		delivery_method :smtp, { 
		    :address => 'email-smtp.us-east-1.amazonaws.com',
		    :port => '587',
		    :user_name => 'AKIAI2R3CISWP2RWKJGA',
		    :password => 'At7lxX0rtF3814Kr4mwrZTWO39kFZ1Kg+iRMhi1pjWPp',
		    :authentication => :plain,
		    :enable_starttls_auto => true
		  }
	end	

	# Another logging option...
	# Logger.class_eval { alias :write :'<<' }
	# #log_file_path = File.join(File.expand_path(__FILE__), '..', 'logs', 'video_process_worker.log')
	# $logger = Logger.new('logs/video_process_worker.log', 'weekly')
	# set :logging, Logger::DEBUG
	# use Rack::CommonLogger, $logger
	# AVUtils.logger = $logger
end

configure :development do
	enable :dump_errors, :show_exceptions
	disable :raise_errors

	# Setting folders
	set :remakes_folder, "C:/Development/Homage/Algo/Remakes/"
	set :contour_folder, "C:/Development/Homage/Algo/Contours/"

	# Process Footage Queue
	process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueueTest"
    set :process_footage_queue, AWS::SQS.new.queues[process_footage_queue_url]

	# Process Render Queue
	render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
    set :render_queue, AWS::SQS.new.queues[render_queue_url]

    # Test DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	# Setting the push client
	set :push_client, HomagePush::Client.development

	# in debug logging into the console
	set :logging, Logger::DEBUG
	AVUtils.logger = ENV['rack.logger']
end

configure :test do
	enable :dump_errors 
	disable :raise_errors, :show_exceptions

	# Setting folders
	set :remakes_folder, "Z:/Remakes/" # "C:/Users/Administrator/Documents/Remakes/"
	set :contour_folder, "C:/Users/Administrator/Documents/Contours/"

	# Process Footage Queue
	process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueueTest"
    set :process_footage_queue, AWS::SQS.new.queues[process_footage_queue_url]

	# Process Render Queue
	render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
    set :render_queue, AWS::SQS.new.queues[render_queue_url]

    # Test DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	# Setting the push client
	set :push_client, HomagePush::Client.development

	set :logging, Logger::DEBUG

	# Logging to file
	logging_dir = File.dirname(File.expand_path(__FILE__)) + "/logs"
	FileUtils.mkdir logging_dir unless File.directory?(logging_dir)
  	log_file = File.new(logging_dir + '/video_process_worker.log', "a+")
  	log_file.sync = true
 	$stdout.reopen(log_file)
  	$stderr.reopen(log_file)
  	#$logger = Logger.new(log_file, 'daily')
end	

configure :production do
	enable :dump_errors
	disable :raise_errors, :show_exceptions

	# Setting folders
	set :remakes_folder, "Z:/Remakes/" # "C:/Users/Administrator/Documents/Remakes/"
	set :contour_folder, "C:/Users/Administrator/Documents/Contours/"

	# Process Footage Queue
	process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueue"
    set :process_footage_queue, AWS::SQS.new.queues[process_footage_queue_url]

	# Process Render Queue
	render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueue"
    set :render_queue, AWS::SQS.new.queues[render_queue_url]

    # DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod")
	set :db, db_connection.db()

	# Setting the push client
	set :push_client, HomagePush::Client.production

	set :logging, Logger::INFO

	# Logging to file
	logging_dir = File.dirname(File.expand_path(__FILE__)) + "/logs"
	FileUtils.mkdir logging_dir unless File.directory?(logging_dir)
  	log_file = File.new(logging_dir + '/video_process_worker.log', "a+")
  	log_file.sync = true
 	$stdout.reopen(log_file)
  	$stderr.reopen(log_file)
end	

# before do
# 	env['rack.logger'] = $logger
# end

module FootageStatus
  Open = 0
  Uploaded = 1
  Processing = 2
  Ready = 3
  ProcessFailed = 4
end

module RemakeStatus
  New = 0
  InProgress = 1
  Rendering = 2
  Done = 3
  Timeout = 4
  Deleted = 5
  PendingScenes = 6 			# Waiting for all the scenes to be processed (user requested for a video)
  PendingQueue = 7 				# Waiting in the SQS to be processed
  Failed = 8					# Something went wrong
  ClientRequestedDeletion = 9
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

					# Internal (localhost) request. No need for SSL
					http.use_ssl = false

					# Making the request
					response = http.request(request)
					#http.post('/process', "remake_id=2323, scene_id=2")
					#Net::HTTP.post_form(settings.process_footage_uri, params)

					if response.code != '200' then
					 	raise response.message
					end

					puts 'message sucessfully processed: ' + msg.id + "; " + msg.body
				}
			rescue => error
				puts "rescued, error occured, keeping the polling thread alive. Error: " + error.to_s
				puts  error.backtrace.join("\n")
			end
		end
	end
end

post '/process' do
	begin
		# input
		remake_id = BSON::ObjectId.from_string(params[:remake_id])
		scene_id = params[:scene_id].to_i
		take_id = params[:take_id]

		logger.info "Process footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s + " with take_id " + take_id

		# Fetching the remake and its story
		remakes = settings.db.collection("Remakes")
		remake = remakes.find_one(remake_id)
		story = settings.db.collection("Stories").find_one(remake["story_id"])
		user = settings.db.collection("Users").find_one(remake["user_id"])
		environment = settings.environment.to_s

		# Creating a new directory for the processing
		process_folder = settings.remakes_folder + take_id + "/"

		# Returning an error if the directory exists
		if File.directory?(process_folder) then
			error_message = "process directory already exists for: " + process_folder
			logger.error error_message
			halt 500
		end

		logger.info "Creating temp folder: " + process_folder.to_s
		FileUtils.mkdir process_folder

		# Updating the status of this footage to Processing
		result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Processing}})
		logger.info "Footage status updated to Processing (2) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

		# Downloading the raw video from s3
		raw_video_s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
		raw_video_file_path = process_folder + File.basename(raw_video_s3_key)	
		thumbnail_extension = "_raw1.jpg"
		thumbnail_file_name = remake_id.to_s
		raw_thumbnail_s3_key = File.dirname(raw_video_s3_key).to_s + "/" + thumbnail_file_name + thumbnail_extension
		download_from_s3 raw_video_s3_key, raw_video_file_path

		raw_video = AVUtils::Video.new(raw_video_file_path)

		# Checking if forgeound extraction is needed
		if story["scenes"][scene_id - 1]["silhouette"] or story["scenes"][scene_id - 1]["silhouettes"] then
			# Getting the contour
			contour_path = get_contour_path(remake, story, scene_id)
			processed_video = nil
			if scene_id == 1
				# Processing the video
				processed_video, background_value, first_frame_path = raw_video.process(contour_path,nil,true)
				#upload thumbnail to s3
				s3_upload_thumbnail_object = upload_to_s3 first_frame_path, raw_thumbnail_s3_key, :public_read, 'image/jpeg'
				#Update mongo db with background and thumbnail
				##---------------------------------------------
				if s3_upload_thumbnail_object != nil && processed_video != nil
					if background_value != nil
						remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.background" => background_value}})
					end
					if s3_upload_thumbnail_object.public_url != nil
						remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.raw_thumbnail" => s3_upload_thumbnail_object.public_url.to_s}})
					end
				end
			else
				# Processing the video
				processed_video, background_value, first_frame_path = raw_video.process(contour_path)
			end

			
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

		# Uploading and updating the status of this footage to Ready only if this is the latest take for the scene (else ignoring it)
		if is_latest_take(remake, scene_id, take_id) then
			# upload to s3
			processed_video_s3_key = remake["footages"][scene_id - 1]["processed_video_s3_key"]
			upload_to_s3 processed_video.path, processed_video_s3_key, :private

			result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Ready}})
			logger.info "Footage status updated to Ready (3) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
		else
			logger.info "not updating the DB to status ready since this is not the latest take for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"
		end

		# If remake is ready sending it to the render queue and updating the DB
		if remake_ready?(remake_id) then
			message = {remake_id: remake_id.to_s}
			settings.render_queue.send_message(message.to_json)

			remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::PendingQueue}})
		end

		# Deleting the folder after everything was updated successfully
		logger.info "Deleting temp folder: " + process_folder
		FileUtils.remove_dir(process_folder, true)

		return 200
	rescue => error
		# log the error
		logger.error error.to_s
		logger.error error.backtrace.join("\n")

		# update DB that remake ans footage process failed
		remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Failed}})
		remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::ProcessFailed}})
		# clear visibility timout (ChangeMessageVisibility)
		#AWS::SQS::Client.change_message_visibility({:queue_url => settings.render_queue_url, :receipt_handle => handle, :visibility_timeout => 0})

	    # Sending a mail about the error
	    Mail.deliver do
		  from    'cv-worker-' + environment + '@homage.it'
		  to      'nir@homage.it'
		  subject 'Error while processing video ' + take_id.to_s
		  body    error.to_s + "\n" + error.backtrace.join("\n")
		end

		# Push notification error
		HomagePush.push_video_timeout(remake, user, settings.push_client)

		# renaming the process folder if it exists
		if process_folder then
			original_folder = File.expand_path(process_folder)
			renamed_folder = original_folder + '_backup_' + Time.now.to_i.to_s
			logger.info 'error occured, renaming the process folder to ' + renamed_folder
			File.rename(original_folder, renamed_folder)
		else
			logger.debug 'process folder is nil - nothing to delete'
		end

	end
end

get '/health/check' do
end

def get_contour_path(remake, story, scene_id)
	# Getting the contour
	if remake["resolution"] then
		contour = story["scenes"][scene_id - 1]["contours"][remake["resolution"]]["contour"]
	else
		contour = story["scenes"][scene_id - 1]["contour"]
	end

	contour_path = settings.contour_folder + File.basename(contour)
	return contour_path
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

def upload_to_s3 (file_path, s3_key, acl, content_type=nil)
	s3 = AWS::S3.new
	bucket = s3.buckets['homageapp']
	s3_object = bucket.objects[s3_key]

	logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
	#file = File.new(file_path)
	s3_object.write(Pathname.new(file_path), {:acl => acl, :content_type => content_type})
	#file.close
	logger.info "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s

	return s3_object
end

def is_latest_take(remake, scene_id, take_id)
	db_take_id = remake["footages"][scene_id - 1]["take_id"]
	if db_take_id then
		if db_take_id == take_id then
			return true
		else
			logger.info "Not the latest take for remake <" + remake["_id"].to_s + ">, footage <" + scene_id.to_s + ">. DB take_id <" + db_take_id + "> while given take_id <" + take_id + ">"
			return false
		end
	else
		# No take_id then assuiming this is the latest one
		return true
	end
end

# This method checks the set of rules if the current remake is ready to be sent to the render queue
	# 1. User clicked on "Create Movie" (status of remake is pending for scenes to complete)
	# 2. All scenes are processed
def remake_ready?(remake_id)
	remake = settings.db.collection("Remakes").find_one(remake_id)

	logger.info "Checking if remake " + remake_id.to_s + " is ready for render"
	if remake["status"] == RemakeStatus::PendingScenes then
		logger.info "Remake " + remake_id.to_s + " is in status PendignScenes, now checking if all scenes are processed"

		scenes_number = remake["footages"].count
		scenes_ready = 0
		for footage in remake["footages"] do
			if footage["status"] == FootageStatus::Ready then
				scenes_ready += 1
			end
		end

		if scenes_ready == scenes_number then
			logger.info "Remake " + remake_id.to_s + " is ready for render"
			return true	
		else
			logger.info "Remake " + remake_id.to_s + " has only " + scenes_ready.to_s + " out of " + scenes_number.to_s + " processed, hence is not ready"
			return false
		end 

	else
		logger.info "Remake " + remake_id.to_s + " is not in status PendingScenes, hence is not ready"
		return false
	end
end
