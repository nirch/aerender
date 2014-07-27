require 'aws-sdk'
	

# Getting an SQS object
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)

sqs = AWS::SQS.new

# Getting the ProcessFootageQueue
process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueueTest"
process_footage_queue = sqs.queues[process_footage_queue_url]

puts process_footage_queue.url

message = {remake_id: ARGV[0], scene_id: ARGV[1], take_id: ARGV[2]}
process_footage_queue.send_message(message.to_json)