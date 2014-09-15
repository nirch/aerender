
module HomagePush
	class Client
		# apn (Apple Push Notification)
		# gcm (Google Cloud Messaging)
		attr_accessor :apn, :gcm 

		class << self
			def development
				client = self.new

				# Google Cloud Messaging 
				client.gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")

				# Apple Push Notification
				client.apn = Houston::Client.development
				client.apn.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_dev.pem", __FILE__))

				client
			end

			def production
				client = self.new

				# Google Cloud Messaging 
				client.gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")

				# Apple Push Notification
				client.apn = Houston::Client.production
				client.apn.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_prod.pem", __FILE__))
				client.apn.passphrase = "homage"

				client
			end
	    end

	    def push_ios(token, message, data)
	    	HomagePush.logger.info "Sending push notification to ios device token: " + token.to_s + " with message: " + message + " with data: " + data.to_s
			notification = Houston::Notification.new(device: token)
			notification.alert = message
			notification.custom_data = data
			notification.sound = "default"
			@apn.push(notification)	
	    end

	    def push_android(token, message ,data)
			HomagePush.logger.info "Sending push notification to android device token: " + token.to_s + " with message: " + message + " with data: " + data.to_s
			tokens = [token]
			data[:text] = message
			data = {data: data}
			response = @gcm.send(tokens, data)
			HomagePush.logger.debug response
	    end
	end
end