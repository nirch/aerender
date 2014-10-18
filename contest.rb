#encoding: utf-8
require 'sinatra'
require 'aws-sdk'
require 'bson'
require 'mail'
require 'sinatra/subdomain'
require 'mixpanel-ruby'

configure do
	# Global configuration (regardless of the environment)

	# AWS Connection
	aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
	AWS.config(aws_config)

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

	# Setting MixPanel
	set :mixpanel, Mixpanel::Tracker.new("7d575048f24cb2424cd5c9799bbb49b1")

    # Logging to file
    set :logging, Logger::DEBUG
    logging_dir = File.dirname(File.expand_path(__FILE__)) + "/logs"
    FileUtils.mkdir logging_dir unless File.directory?(logging_dir)
    log_file = File.new(logging_dir + '/contest.log', "a+")
    log_file.sync = true
    $stdout.reopen(log_file)
    $stderr.reopen(log_file)
end

get '/' do
	settings.mixpanel.track("12345", "ContestFlyer")
	redirect "https://www.smore.com/qbzm5", 302
end

get '/form' do
	erb :contest_form
end

post '/form' do
    first_name = params[:first_name]
    last_name = params[:last_name]
    email = params[:email]
    country = params[:country]
    address = params[:address]
    birth_date = params[:birth_date]
    gender = params[:gender]
    about_submission = params[:about_submission]
    profession = params[:profession]
    feedback = params[:feedback]
    file = params[:file][:tempfile]
    file_name = params[:file][:filename]


    # Text file to upload to S3
    text_file = File.new(first_name + "_" + last_name + ".txt", "w+")
    text_file.puts "First Name: " + first_name
    text_file.puts "Last Name: " + last_name
    text_file.puts "E-mail: " + email
    text_file.puts "Country: " + country
    text_file.puts "Address: " + address
    text_file.puts "Birth Date: " + birth_date
    text_file.puts "Gender: " + gender
    text_file.puts "About Submission: " + about_submission
    text_file.puts "Profession: " + profession
    text_file.puts "Feedback: " + feedback
    text_file.close

    unique_id = BSON::ObjectId.new.to_s
    name_with_unique = first_name + ' ' + last_name + ' (' + unique_id + ')'
    s3_fodler = 'Uploads/' + name_with_unique + '/'

    # Uploading text file to S3
    s3_text_destination = s3_fodler + name_with_unique + ".txt"
    upload_to_s3_path("homage-contest", text_file.path, s3_text_destination)

    # Sending a mail about the new submission
    Mail.deliver do
	  from    'homage-server-app@homage.it'
	  to      'ran@homage.it'
	  subject 'New Contest Submission From: ' + name_with_unique
	  body    File.read(text_file.path)
	end

    # Deleting text file
    File.delete(text_file.path)

    # Uploading the AE project - Doing it in another thread to avoid timeout
    s3_destination = s3_fodler + file_name
    Thread.new{
	    upload_to_s3_path("homage-contest", file.path, s3_destination)
	}

    "Your application was successfully submitted. Good Luck!"
end	

def upload_to_s3_path(s3_bucket, file_path, s3_key)
	s3 = AWS::S3.new
	bucket = s3.buckets[s3_bucket]
	s3_object = bucket.objects[s3_key]

	logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
	s3_object.write(:file => file_path)
	logger.info "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s
	return s3_object
end

