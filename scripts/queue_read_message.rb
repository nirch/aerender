require 'aws-sdk'
	

# Getting an SQS object
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)
sqs = AWS::SQS.new

# Getting the RenderQueue
process_render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
process_render_queue = sqs.queues[process_render_queue_url]

# Polling for new messages and printing the message body
process_render_queue.poll{ |msg|

	puts "body: " + msg.body
	puts "receive_count: " + msg.receive_count.to_s

}