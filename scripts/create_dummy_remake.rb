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

def s3_upload(file_path, s3_key, acl, content_type=nil)
	s3_object = S3_HOMAGE_BUCKET.objects[s3_key]
	#logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
	file = File.new(file_path)
	s3_object.write(file, {:acl => acl, :content_type => content_type})
	file.close
	#puts "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s
	return s3_object
end

remake_id = BSON::ObjectId.new
story_id = BSON::ObjectId.from_string('535e8fc981360cd22f0003d4') # Superior Man
user_id = BSON::ObjectId.from_string('5332ec99f52d5c1ec2000017') # nirh2@yahoo.com

story = STORIES.find_one(story_id)

s3_folder = "Remakes" + "/" + remake_id.to_s + "/"
s3_video = s3_folder + story["name"] + "_" + remake_id.to_s + ".mp4"
s3_thumbnail = s3_folder + story["name"] + "_" + remake_id.to_s + ".jpg"

remake = {_id: remake_id, story_id: story_id, user_id: user_id, created_at: Time.now ,status: 0, 
	thumbnail: story["thumbnail"], video_s3_key: s3_video, thumbnail_s3_key: s3_thumbnail, resolution: "360"}

footages = Array.new

# Scene 1
s3_destination_raw = s3_folder + "raw_" + "scene_" + 1.to_s + ".mov"
s3_destination_processed = s3_folder + "processed_" + "scene_" + 1.to_s + ".mov"
footage = {scene_id: 1, status: 0, raw_video_s3_key: s3_destination_raw, processed_video_s3_key: s3_destination_processed, :take_id => 'VID_20140720_160644'}
footages.push(footage)

remake[:footages] = footages

REMAKES.save(remake)

remake = REMAKES.find_one(remake_id)

file_to_upload = '../tests/resources/360_right_side_up_audio.mov'
upload_to = remake["footages"][0]["raw_video_s3_key"]
s3_key = s3_upload(file_to_upload, upload_to, :private)

result = {:remake_id => remake["_id"].to_s, :scene_id => "1", :take_id => remake["footages"][0]["take_id"]}

puts result