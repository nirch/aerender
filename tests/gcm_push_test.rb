require 'gcm'
require 'json'

gcm = GCM.new("AIzaSyBLZSS5D3k07As3GS2HXKc8aMqV8xh5KSQ")
tokens = ["APA91bE4MZmyhKWNiYyecfa8r0cHzai6KGv_LJTz59mdWlCFUQ_Y6fIu9U3V0myH7yfKWL3qr_ru8f4xkThOVsTtbbaSFwiZpBryF6zy9At4h3Q7ySQQEbKQMfH1PXYzJwm_HykxTltsHZDaykGNZj5c6Fv3TFKtyw"]
data = {data: {title: "Good Nigh!", text: "bye bye"}}
response = gcm.send(tokens, data)
puts response
