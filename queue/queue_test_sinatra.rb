require 'sinatra'
require 'aws-sdk'

configure do
	# Global configuration (regardless of the environment)

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
					http.request(request)
					#http.post('/process', "remake_id=2323, scene_id=2")
					#Net::HTTP.post_form(settings.process_footage_uri, params)
				}
			rescue
				puts "rescued, exception happend, keeping the polling thread alive"
			end
		end
	end
end

post '/process' do
	logger.info "params = " + params.to_s
	sleep 100
	logger.info "successfully processed"
	return "success"
end