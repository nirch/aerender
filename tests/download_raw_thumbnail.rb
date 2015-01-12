require '../utils/aws/homage_aws'
require 'mongo'
require 'time'


TEST_DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db()
PROD_DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod").db()

db = PROD_DB
s3 = HomageAWS::HomageS3.production

remakes_collection = db.collection("Remakes")


date = Time.parse("20141230Z")
remakes = remakes_collection.find(created_at:{"$gte"=>date}, status:3).limit(1)

for remake in remakes do
	remake_id = remake['_id'].to_s
	s3_key = 'Remakes/' + remake_id + '/' + remake_id + '_' + remake_id + '_raw1.jpg'
	puts s3_key
end
# remakes = prod_remakes.find(created_at:{"$gte"=>start_date, "$lt"=>add_days(end_date,1)},_id: {"$in" => remake_array})

