require 'aws-sdk'
	

# Getting an SQS object
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)
sqs = AWS::SQS.new

# Getting the ProcessFootageQueue
process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueueTest"
process_footage_queue = sqs.queues[process_footage_queue_url]

# Polling for new messages and printing the message body
process_footage_queue.poll{ |msg|
	puts JSON.parse(msg.body)
}