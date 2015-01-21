
module HomagePush
	class Client
		# apn (Apple Push Notification)
		# gcm (Google Cloud Messaging)
		attr_accessor :apn, :gcm, :apn_new

		class << self
			def development
				# Homage Push Client
				homage_client = self.new
				# Google Cloud Messaging 
				homage_client.gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")
				# Apple Push Notification
				homage_client.apn = Houston::Client.development
				homage_client.apn.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_dev.pem", __FILE__))
				# Apple Push Notification - For new client (version 1.5.0 and up)
				homage_client.apn_new = Houston::Client.production
				homage_client.apn_new.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_prod_150.pem", __FILE__))
				homage_client.apn_new.passphrase = "homage"

				# Monkey Push Client
				monkey_client = self.new
				# Google Cloud Messaging - No Android Support...
				# Apple Push Notification
				monkey_client.apn = Houston::Client.development
				monkey_client.apn.certificate = File.read(File.expand_path("../../../certificates/monkey_push_notification_dev.pem", __FILE__))

				return Hash["544ead1e454c610d1600000f" => homage_client, "54919516454c61f4080000e5" => monkey_client]
			end

			def production
				homage_client = self.new

				# Google Cloud Messaging 
				homage_client.gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")

				# Apple Push Notification
				homage_client.apn = Houston::Client.production
				homage_client.apn.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_prod.pem", __FILE__))
				homage_client.apn.passphrase = "homage"

				# Apple Push Notification - For new client (version 1.5.0 and up)
				homage_client.apn_new = Houston::Client.production
				homage_client.apn_new.certificate = File.read(File.expand_path("../../../certificates/homage_push_notification_prod_150.pem", __FILE__))
				homage_client.apn_new.passphrase = "homage"

				# Monkey Push Client
				monkey_client = self.new
				# Google Cloud Messaging - No Android Support...
				# Apple Push Notification
				monkey_client.apn = Houston::Client.production
				monkey_client.apn.certificate = File.read(File.expand_path("../../../certificates/monkey_push_notification_prod.pem", __FILE__))
				monkey_client.apn_new.passphrase = "homage"

				return Hash["544ead1e454c610d1600000f" => homage_client, "54919516454c61f4080000e5" => monkey_client]
			end
	    end

	    def push_ios(token, message, data)
	    	HomagePush.logger.info "Sending push notification to ios device token: " + token.to_s + " with message: " + message + " with data: " + data.to_s
			notification = Houston::Notification.new(device: token)
			notification.alert = message
			notification.custom_data = data
			notification.sound = "default"
			@apn.push(notification)	
			@apn_new.push(notification)
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