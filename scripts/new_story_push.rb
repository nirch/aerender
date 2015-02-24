require 'mongo'
require 'date'
require 'time'
require_relative '../utils/push/Homage_Push'

# Mongo connection
test_db = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db
prod_db = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod").db
db = prod_db

users_collection = db.collection("Users")
stories_collection = db.collection("Stories")

# Push client
push_client = HomagePush::Client.production

# New Story
message = "Do the Maccabi TLV Dance! Win a Trip to Europe!"
story_id = BSON::ObjectId.from_string("54e896266461747f303f0000")
story = stories_collection.find_one(story_id)

# Getting all the users
date_input = "20140430Z"
from_date = Time.parse(date_input)
homage_campaign = BSON::ObjectId.from_string("544ead1e454c610d1600000f")
users = users_collection.find(created_at:{"$gte"=>from_date}, campaign_id:homage_campaign)

for user in users do
	# Push notification for video ready
	begin
		HomagePush.push_new_story(story, message, user, push_client["544ead1e454c610d1600000f"])
	rescue => error
		puts error
	end
end

# # Test on Nir's user
# user = users_collection.find_one(BSON::ObjectId.from_string("5332ec99f52d5c1ec2000017"))
# HomagePush.push_new_story(story, message, user, push_client)
