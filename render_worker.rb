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

	drive = ENV['drive'] ? ENV['drive'] : "Z:"
	user = ENV['user'] ? ENV['user'] : "Administrator"

	# Setting folders
	set :ae_projects_folder, "C:/Users/" + user + "/Documents/AE Projects/"
	set :output_folder, drive + "/Output/" # "C:/Users/Administrator/Documents/AE Output/"
	set :cdn_folder, drive + "/CDN/"

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

	render_url = "http://localhost:" + settings.port.to_s + "/render"
	set :render_uri, URI.parse(render_url)

	AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'
	AVUtils.aerender_binary = 'C:/Program Files/Adobe/Adobe After Effects CC/Support Files/aerender.exe'

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
end

configure :development do
	enable :dump_errors, :show_exceptions
	disable :raise_errors

	# Setting folders
	set :ae_projects_folder, "C:/Users/Channes/Documents/AE Projects/"
	set :output_folder, "C:/Development/Homage/After/Ouput/"
	set :cdn_folder,  "C:/Development/Homage/After/CDN/"
	set :s3_bucket_path, "https://homagetest.s3.amazonaws.com/"
	set :cdn_path, "http://d2m9jhdu5nhw9c.cloudfront.net/"


	# Process Footage Queue
	set :render_queue_url, "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
    set :render_queue, AWS::SQS.new.queues[settings.render_queue_url]

    # Test DB connection
    set :db_client, Mongo::Client.new(['paulo.mongohq.com:10008'], :database => 'Homage', :user => 'Homage', :password => 'homageIt12')

	# AWS S3
	s3 = AWS::S3.new
	set :bucket, s3.buckets['homagetest']

	# in development logging into the console
	set :logging, Logger::DEBUG
	AVUtils.logger = ENV['rack.logger']

	# Setting the push client
	set :push_client, HomagePush::Client.development
	HomagePush.logger = ENV['rack.logger']
end

configure :test do
	enable :dump_errors 
	disable :raise_errors, :show_exceptions

	# Setting folders
	set :s3_bucket_path, "https://homagetest.s3.amazonaws.com/"
	set :cdn_path, "http://d2m9jhdu5nhw9c.cloudfront.net/"

	# Process Footage Queue
	set :render_queue_url, "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
    set :render_queue, AWS::SQS.new.queues[settings.render_queue_url]

    # Test DB connection
    set :db_client, Mongo::Client.new(['paulo.mongohq.com:10008'], :database => 'Homage', :user => 'Homage', :password => 'homageIt12')

	# AWS S3
	s3 = AWS::S3.new
	set :bucket, s3.buckets['homagetest']

	set :share_link_prefix, "http://homage-server-app-dev.elasticbeanstalk.com/play/"

	# Setting the push client
	set :push_client, HomagePush::Client.development

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
	set :s3_bucket_path, "https://homageapp.s3.amazonaws.com/"
	set :cdn_path, "http://d293iqusjtyr94.cloudfront.net/"

	# Process Footage Queue
	set :render_queue_url, "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueue"
    set :render_queue, AWS::SQS.new.queues[settings.render_queue_url]

    # DB connection
    set :db_client, Mongo::Client.new(['troup.mongohq.com:10057'], :database => 'Homage_Prod', :user => 'Homage', :password => 'homageIt12')

	# AWS S3
	s3 = AWS::S3.new
	set :bucket, s3.buckets['homageapp']

	set :share_link_prefix, "http://play.homage.it/"

	# Setting the push client
	set :push_client, HomagePush::Client.production

	set :logging, Logger::INFO

	# Logging to file
	logging_dir = File.dirname(File.expand_path(__FILE__)) + "/logs"
	FileUtils.mkdir logging_dir unless File.directory?(logging_dir)
  	log_file = File.new(logging_dir + '/render_worker.log', "a+")
  	log_file.sync = true
 	$stdout.reopen(log_file)
  	$stderr.reopen(log_file)
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
					http.read_timeout = 300

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
	begin
		environment = settings.environment.to_s

		# input
		remake_id = BSON::ObjectId.from_string(params[:remake_id])
		remakes = settings.db_client[:Remakes]

		# Logging and updating the DB that the rendering has started
		logger.info "Starting the rendering of remake " + remake_id.to_s
		remakes.update_one({_id: remake_id}, {"$set" => {status: RemakeStatus::Rendering}})

		# Getting the remake and story to render
		remake = remakes.find({_id:remake_id}).each.next
		story = settings.db_client[:Stories].find({_id:remake["story_id"]}).each.next
		user = settings.db_client[:Users].find({_id:remake["user_id"]}).each.next
		campaign_id = story["campaign_id"].to_s

		# Getting the AE project details
		story_folder = story["after_effects"][remake["resolution"]]["folder"]
		story_project = story["after_effects"][remake["resolution"]]["project"]

		# copying all videos to after project (downloading them from s3)
		for scene in story["after_effects"]["scenes"] do
			processed_video_s3_key = remake["footages"][scene["id"] - 1]["processed_video_s3_key"]
			destination = settings.ae_projects_folder + story_folder + "/(Footage)/" + scene["file"]
			download_from_s3 processed_video_s3_key, destination
		end

		# Rendering the video with AE
		ae_project_path = settings.ae_projects_folder + story_folder + "/" + story_project
		output_file_name = story["name"].gsub(' ', '_') + "_" + remake_id.to_s + ".mp4"
		output_file_name = output_file_name.gsub('&', 'N')
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
		remakes.update_one({_id: remake_id}, {"$set" => {status: RemakeStatus::Done, video: video_cdn_url, thumbnail: thumbnail_cdn_url, share_link: share_link, render_end: render_end, render_duration: render_duration, grade:-1}})
		logger.info "Updating DB: remake " + remake_id.to_s + " with status Done and url to video: " + video_cdn_url

		# Push notification for video ready
		HomagePush.push_video_ready(story, remake, user, settings.push_client[campaign_id])

		cdn_local_path = settings.cdn_folder + output_file_name
		logger.info "downloading the just created video to update CDN cache"
		download_from_url(video_cdn_url, cdn_local_path)
		logger.info "Now deleting the file that was downloaded for cache"
		FileUtils.remove_file(cdn_local_path)

		update_story_remakes_count(story["_id"])

		return 200
	rescue => error	
		# log the error
		logger.error error.to_s
		logger.error error.backtrace.join("\n")

	    # Sending a mail about the error
	    Mail.deliver do
		  from    'render-worker-' + environment + '@homage.it'
		  to      'nir@homage.it'
		  subject 'Error while rendering remake ' + remake_id.to_s
		  body    error.to_s + "\n" + error.backtrace.join("\n")
		end

		# update DB that remake failed + clear visibility timout (ChangeMessageVisibility)
		remakes.update_one({_id: remake_id}, {"$set" => {status: RemakeStatus::Failed}})
		#AWS::SQS::Client.change_message_visibility({:queue_url => settings.render_queue_url, :receipt_handle => handle, :visibility_timeout => 0})

		# Push notification error
		HomagePush.push_video_timeout(remake, user, settings.push_client[campaign_id])

		logger.info "failed push notification sent successfully"
	end
end

def update_story_remakes_count(story_id)
	remakes = settings.db_client[:Remakes]
	stories = settings.db_client[:Stories]

	# Getting the number of remakes for this story
	story_remakes = remakes.count({story_id: story_id, share_link: {"$exists" => true}})

	stories.update_one({_id: story_id}, {"$set" => {"remakes_num" => story_remakes}})
	logger.info "Updated story id <" + story_id.to_s + "> number of remakes to " + story_remakes.to_s
end

def download_from_url (url, local_path)
	File.open(local_path, 'wb') do |file|
		file << open(url).read
    end	
end

def download_from_s3 (s3_key, local_path)
	bucket = settings.bucket

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
	bucket = settings.bucket
	s3_object = bucket.objects[s3_key]

	logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
	#file = File.new(file_path)
	s3_object.write(Pathname.new(file_path), {:acl => acl, :content_type => content_type})
	#file.close
	logger.info "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s

	return s3_object
end


get '/test/env' do
	settings.ae_projects_folder + " ----- " + settings.output_folder + " -------- " + settings.cdn_folder
end
