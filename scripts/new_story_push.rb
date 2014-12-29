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
push_client = HomagePush::Client.development

# New Story
message = "Create your own Holiday clip! Merry Christmas!!"
story_id = BSON::ObjectId.from_string("5492fe00454c61672c000489")
story = stories_collection.find_one(story_id)

# Getting all the users
date_input = "20140430Z"
from_date = Time.parse(date_input)
users = users_collection.find(created_at:{"$gte"=>from_date})

for user in users do
	# Push notification for video ready
	HomagePush.push_new_story(story, message, user, push_client)
end

# # Test on Nir's user
# user = users_collection.find_one(BSON::ObjectId.from_string("5332ec99f52d5c1ec2000017"))
# HomagePush.push_new_story(story, message, user, push_client)
