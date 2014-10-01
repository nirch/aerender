require 'sinatra'
require 'aws-sdk'
require 'mongo'
require_relative 'video/AVUtils'

configure do
	# Global configuration (regardless of the environment)
	set :server, 'webrick'

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	process_footage_url = "http://localhost:" + settings.port.to_s + "/process"
	set :process_footage_uri, URI.parse(process_footage_url)

	AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'
	AVUtils.algo_binary = 'C:/Development/Algo/v-14-09-29/UniformMattingCA.exe'
	AVUtils.algo_params = 'C:/Development/Algo/params.xml'

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
end

module RemakeStatus
  New = 0
  InProgress = 1
  Rendering = 2
  Done = 3
  Timeout = 4
  Deleted = 5
  PendingScenes = 6
  PendingQueue = 7
  Failed = 8
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
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])
	scene_id = params[:scene_id].to_i
	take_id = params[:take_id]

	logger.info "Process footage for scene " + scene_id.to_s + " for remake " + remake_id.to_s + " with take_id " + take_id

	# Fetching the remake and its story
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	# Creating a new directory for the processing
	#@process_folder = settings.remakes_folder + remake_id.to_s + "_scene_" + scene_id.to_s + "_" + take_id + "/"
	@process_folder = settings.remakes_folder + take_id + "/"

	# Returning an error if the directory exists
	if File.directory?(@process_folder) then
		error_message = "process directory already exists for: " + @process_folder
		logger.error error_message
		halt 500
	end

	logger.info "Creating temp folder: " + @process_folder.to_s
	FileUtils.mkdir @process_folder

	# Updating the status of this footage to Processing
	result = remakes.update({_id: remake_id, "footages.scene_id" => scene_id}, {"$set" => {"footages.$.status" => FootageStatus::Processing}})
	logger.info "Footage status updated to Processing (2) for remake <" + remake_id.to_s + ">, footage <" + scene_id.to_s + ">"

	# Downloading the raw video from s3
	raw_video_s3_key = remake["footages"][scene_id - 1]["raw_video_s3_key"]
	raw_video_file_path = @process_folder + File.basename(raw_video_s3_key)	
	download_from_s3 raw_video_s3_key, raw_video_file_path

	raw_video = AVUtils::Video.new(raw_video_file_path)

	# Checking if forgeound extraction is needed
	if story["scenes"][scene_id - 1]["silhouette"] or story["scenes"][scene_id - 1]["silhouettes"] then
		# Getting the contour
		contour_path = get_contour_path(remake, story, scene_id)

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

	#handle_send_to_render_queue(remake_id)

	# Deleting the folder after everything was updated successfully
	logger.info "Deleting temp folder: " + @process_folder
	FileUtils.remove_dir(@process_folder, true)

	return 200

end


error do
	logger.error 'error caught in error block: ' + env['sinatra.error'].to_s

	# renaming the process folder if it exists
	if @process_folder then
		original_folder = File.expand_path(@process_folder)
		renamed_folder = original_folder + '_backup_' + Time.now.to_i.to_s
		logger.info 'error occured, renaming the process folder to ' + renamed_folder
		File.rename(original_folder, renamed_folder)
	else
		logger.debug 'process folder is nil - nothing to delete'
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
def handle_send_to_render_queue(remake_id)
	remake = settings.collection("Remakes").find_one(remake_id)

	# Resturns if the user didn't press on "Create Movie"
	return unless remake["status"] == RemakeStatus::PendingScenes

	scenes_number = remake["footages"].count
	scenes_ready = 0
	for footage in remakes["footages"] do
		if footage["status"] == FootageStatus::Ready then
			scenes_ready += 1
		end
	end

	# Returns if not all scenes are ready
	return unless scenes_ready == scenes_number

	# Got here?! - Send render to queue!
	message = {remake_id: remake_id.to_s}
	settings.render_queue.send_message(message.to_json)

	# Update the DB that the remake is in the render queue
	remakes = settings.db.collection("Remakes")
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::PendingQueue}})

end
