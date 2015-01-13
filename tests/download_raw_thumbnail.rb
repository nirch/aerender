require '../utils/aws/homage_aws'
require 'mongo'
require 'time'
require 'open-uri'


TEST_DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db()
PROD_DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod").db()

db = PROD_DB
s3 = HomageAWS::HomageS3.production

remakes_collection = db.collection("Remakes")
stories_collection = db.collection("Stories")
download_folder = "C:/Users/homage/Documents/Data/Backgroud/Prod"

date = Time.parse("20150111Z")
remakes = remakes_collection.find(created_at:{"$gte"=>date}, status:3).limit(1)

for remake in remakes do
	remake_id = remake['_id'].to_s
	story = stories_collection.find_one(remake["story_id"])

	# Downloading thumbnail
	thumbnail_s3_key = 'Remakes/' + remake_id + '/' + remake_id + '_raw1.jpg'
	thumbnail_download_path = File.join download_folder, remake_id + ".jpg"
	s3.download thumbnail_s3_key, thumbnail_download_path

	# Downloading video
	video_s3_key = 'Remakes/' + remake_id + '/' + 'raw_scene_1.mov'
	video_download_path = File.join download_folder, remake_id + ".mov"
	s3.download video_s3_key, video_download_path

	# Downloading contour
	contour_orig_url = story["scenes"][0]["contours"]["360"]["contour_remote"]
	contour_face_url = File.dirname(contour_orig_url) + "/Face/" + File.basename(contour_orig_url,".*") + "-face.ctr"
	contour_download_path = File.join download_folder, remake_id + ".ctr"

	puts "Downloading file " + File.basename(contour_face_url) + "..."
	open(contour_download_path, 'wb') do |file|
		file << open(contour_face_url).read
	end
end