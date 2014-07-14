require 'aws-sdk'
	

# Getting an SQS object
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)
sqs = AWS::SQS.new

# Getting the ProcessFootageQueue
process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueue"
process_footage_queue = sqs.queues[process_footage_queue_url]

puts process_footage_queue.url

message = {remake_id: "53c2973070b35d0a7c000016", scene_id: 1}
process_footage_queue.send_message(message.to_s)