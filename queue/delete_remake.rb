require 'mongo'
require 'aws-sdk'

DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db()
REMAKES = DB.collection("Remakes")
STORIES = DB.collection("Stories")


# AWS Connection
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)
s3 = AWS::S3.new
S3_HOMAGE_BUCKET = s3.buckets['homageapp']


remake_to_delete = '53d02577d8ea2009a0000001'
remake_id_to_delete = BSON::ObjectId.from_string(remake_to_delete)
remake_s3 = "Remakes/" + remake_to_delete

remake = REMAKES.find_one(remake_id_to_delete)
if remake then
	puts 'Mongo: remake found now deleting it...'
	REMAKES.remove({_id:remake_id_to_delete})
	remake = REMAKES.find_one(remake_id_to_delete)
	if remake then
		puts "something went wrong deleting from mongo"
	else
		puts "deleted successfully from mongo"
	end
else
	puts "remake wasn't found in mongo"
end


if S3_HOMAGE_BUCKET.objects.with_prefix(remake_s3).count > 0 then
	number = S3_HOMAGE_BUCKET.objects.with_prefix(remake_s3).count
	puts 'S3: remake found now deleting it... ' + number.to_s + " objects found" 
	S3_HOMAGE_BUCKET.objects.with_prefix(remake_s3).delete_all
	if S3_HOMAGE_BUCKET.objects.with_prefix(remake_s3).count > 0 then
		puts "something went wrong deleting from s3"
	else
		puts "deleted successfully from s3"
	end
else
	puts "remake wasn't found in S3"
end