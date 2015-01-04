
module HomageAWS
	class HomageSQS

		attr_accessor :cv_queue, :render_queue

		class << self
			def test
				homage_sqs = self.new

				cv_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueueTest"
			    homage_sqs.cv_queue = AWS::SQS.new.queues[cv_queue_url]

			    render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueueTest"
    			homage_sqs.render_queue = AWS::SQS.new.queues[render_queue_url]

				return homage_sqs
			end

			def production
				homage_sqs = self.new

				cv_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueue"
			    homage_sqs.cv_queue = AWS::SQS.new.queues[cv_queue_url]

			    render_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/RenderQueue"
    			homage_sqs.render_queue = AWS::SQS.new.queues[render_queue_url]

				return homage_sqs
			end
	    end

	    #def send_message
	end
end