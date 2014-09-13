
module HomagePush
	class Client
		@apn # Apple Push Notification
		@gcm # Google Cloud Messaging

		class << self
			def development
				client = self.new

				# Google Cloud Messaging 
				@gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")

				# Apple Push Notification
				@apn = Houston::Client.development
				@apn.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_dev.pem", __FILE__))

				client
			end

			def production
				client = self.new

				# Google Cloud Messaging 
				@gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")

				# Apple Push Notification
				@apn = Houston::Client.production
				@apn.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_prod.pem", __FILE__))
				@apn.passphrase = "homage"

				client
			end
	    end

	    def push_ios(token, message, data)
	    	logger.info "Sending push notification to ios device token: " + token.to_s + " with alert: " + alert + " with custom_data: " + data.to_s
			notification = Houston::Notification.new(device: token)
			notification.alert = message
			notification.custom_data = data
			notification.sound = "default"
			@apn.push(notification)	
	    end

	    def push_android(token, message ,data)
			logger.info "Sending push notification to android device token: " + token.to_s + " with alert: " + alert + " with custom_data: " + custom_data.to_s
			tokens = [device_token]
			data[:text] = message
			data = {data: data}
			@gcm.send(tokens, data)
	    end
	end
end