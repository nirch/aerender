#### Pushing using util class (HomagePush)
###########################################

require_relative '../utils/push/Homage_Push'

push_client = HomagePush::Client.production
token = "<789dff12 07993bf8 da73f528 8b181830 86fb059e 279ed2af a1ed1eb0 4ba64b1f>" # Homage
#data = {type: HomagePush::VideoReady, title: "Video is Ready!", remake_id: "5415863ab8fef16bc5000012", story_id: "53ce9bc405f0f6e8f2000655"}
data = {type: 2, story_id: "53b17db89a452198f80004a6"}
message = "Your Street Fighter Video is Ready!"
push_client["544ead1e454c610d1600000f"].push_ios(token, message, data)


#### Pushing directly using Houston
####################################

# require 'houston'

# APN_NEW = Houston::Client.production
# APN_NEW.certificate = File.read("../certificates/homage_push_notification_prod.pem")

# # Nir's iPhone 6
# #token = "<607cd0ea a5bb46fe 4fba2fd7 a397b0b1 e6d81c4f 6adf8e16 b5ef918d ba072868>" Emu
# token = "<789dff12 07993bf8 da73f528 8b181830 86fb059e 279ed2af a1ed1eb0 4ba64b1f>" # Homage

# # Create a notification that alerts a message to the user, plays a sound, and sets the badge on the app
# notification = Houston::Notification.new(device: token)
# notification.alert = "Take Part in the World Cup! Vamos!"
# notification.sound = "default"
# notification.custom_data = {type: 2, story_id: "53b17db89a452198f80004a6"}

# # And... sent! That's all it takes.
# APN_NEW.push(notification)