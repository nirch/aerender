require 'sinatra'
require 'aws-sdk'
require 'mongo'
require_relative 'video/AVUtils'

configure do
	# Global configuration (regardless of the environment)
	set :server, 'webrick'

	# Setting folders
	set :ae_projects_folder, "C:/Users/Administrator/Documents/AE Projects/"
	set :output_folder, "Z:/Output/" # "C:/Users/Administrator/Documents/AE Output/"
	set :cdn_path, "http://d293iqusjtyr94.cloudfront.net/"
	set :s3_bucket_path, "https://homageapp.s3.amazonaws.com/"

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	render_url = "http://localhost:" + settings.port.to_s + "/render"
	set :render_uri, URI.parse(render_url)

	AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'
end

configure :development do
	enable :dump_errors, :show_exceptions
	disable :raise_errors

	# Setting folders

	# Process Footage Queue
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

	# Process Footage Queue
	render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
    set :render_queue, AWS::SQS.new.queues[render_queue_url]

    # Test DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	set :share_link_prefix, "http://homage-server-app-dev.elasticbeanstalk.com/play/"


	set :logging, Logger::DEBUG

	# Logging to file
	logging_dir = File.dirname(File.expand_path(__FILE__)) + "/logs"
	FileUtils.mkdir logging_dir unless File.directory?(logging_dir)
  	log_file = File.new(logging_dir + '/render_worker.log', "a+")
  	log_file.sync = true
 	$stdout.reopen(log_file)
  	$stderr.reopen(log_file)
  	#$logger = Logger.new(log_file, 'daily')
end	

configure :production do
	enable :dump_errors
	disable :raise_errors, :show_exceptions

	# Setting folders

	# Process Footage Queue
	render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueue"
    set :render_queue, AWS::SQS.new.queues[render_queue_url]

    # DB connection
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod")
	set :db, db_connection.db()

	set :share_link_prefix, "http://play.homage.it/"


	set :logging, Logger::INFO

	# Logging to file
	logging_dir = File.dirname(File.expand_path(__FILE__)) + "/logs"
	FileUtils.mkdir logging_dir unless File.directory?(logging_dir)
  	log_file = File.new(logging_dir + '/render_worker.log', "a+")
  	log_file.sync = true
 	$stdout.reopen(log_file)
  	$stderr.reopen(log_file)
end

PARALLEL_PROCESS_NUM = 1

# Creating X threads that will poll the queue and process the message
for i in 1..PARALLEL_PROCESS_NUM do
	Thread.new do
		while true do
			begin
				settings.render_queue.poll{ |msg|
					puts "message caught on RenderQueue. MessageId: " + msg.id + " MessageBody: " + msg.body

					# Creating an HTTP object and Request object (POST)
					http = Net::HTTP.new(settings.render_uri.host, settings.render_uri.port)
					request = Net::HTTP::Post.new(settings.render_uri.request_uri)

					# Converting the message bpdy to a Hash and adding it to the request
					params = JSON.parse(msg.body)
					request.set_form_data(params)

					# Extending the timeout
					http.read_timeout = 180

					# Internal (localhost) request. No need for SSL
					http.use_ssl = false

					# Making the request
					response = http.request(request)

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

post '/render' do
	# input
	remake_id = BSON::ObjectId.from_string(params[:remake_id])

	logger.info "Starting the rendering of remake " + remake_id.to_s

	# Getting the remake and story to render
	remakes = settings.db.collection("Remakes")
	remake = remakes.find_one(remake_id)
	story = settings.db.collection("Stories").find_one(remake["story_id"])

	# Getting the AE project details
	story_folder = story["after_effects"][remake["resolution"]]["folder"]
	story_project = story["after_effects"][remake["resolution"]]["project"]

	# copying all videos to after project (downloading them from s3)
	for scene in story["after_effects"]["scenes"] do
		processed_video_s3_key = remake["footages"][scene["id"] - 1]["processed_video_s3_key"]
		destination = settings.aeProjectsFolder + story_folder + "/(Footage)/" + scene["file"]
		download_from_s3 processed_video_s3_key, destination
	end

	# Rendering the video with AE
	ae_project_path = settings.ae_projects_folder + story_folder + "/" + story_project
	output_file_name = story["name"] + "_" + remake_id.to_s + ".mp4"
	output_path = settings.output_folder + output_file_name
	rendered_video = AVUtils::Video.aerender(ae_project_path, output_path)

	# Creating a thumbnail from the video
	thumbnail_path = rendered_video.thumbnail(story["thumbnail_rip"])

	# Uploading the movie and thumbnail to S3
	video_s3_key = remake["video_s3_key"]
	thumbnail_s3_key = remake["thumbnail_s3_key"]
	s3_object_video = upload_to_s3 rendered_video.path, video_s3_key, :public_read, 'video/mp4'
	s3_object_thumbnail = upload_to_s3 thumbnail_path, thumbnail_s3_key, :public_read

	# Updating the DB: remake statue, share link, render duration, video and thumbnail URLs
	share_link = settings.share_link_prefix + remake_id.to_s
	video_cdn_url = s3_object_video.public_url.to_s.sub(settings.s3_bucket_path, settings.cdn_path)
	thumbnail_cdn_url = s3_object_thumbnail.public_url.to_s.sub(settings.s3_bucket_path, settings.cdn_path)
	render_end = Time.now
	if remake["render_start"] then
		render_duration = render_end - remake["render_start"]
	end
	remakes.update({_id: remake_id}, {"$set" => {status: RemakeStatus::Done, video: video_cdn_url, thumbnail: thumbnail_cdn_url, share_link: share_link, render_end: render_end, render_duration: render_duration, grade:-1}})
	logger.info "Updating DB: remake " + remake_id.to_s + " with status Done and url to video: " + video_cdn_url


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
