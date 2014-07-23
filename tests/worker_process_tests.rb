#require File.expand_path '../test_helper.rb', __FILE__
require File.expand_path '../worker_test_helper.rb', __FILE__
require '../video_process_worker'

class TestWorkerProcess < MiniTest::Unit::TestCase
	include Rack::Test::Methods

	REMAKES = DB.collection("Remakes")
	#USERS = DB.collection("Users")
	STORIES = DB.collection("Stories")

	def app
		Sinatra::Application
	end

	def setup
		@delete_remake_from_mongo
		@delete_object_from_s3
	end

	def test_health
		get '/health/check'
		assert_equal(200, last_response.status)
	end

	def test_process_360
		# Create remake document
		remake = create_remake
		assert(remake)
		@delete_remake_from_mongo = remake["_id"]

		# Upload video to s3
		file_to_upload = 'resources/360_right_side_up_audio.mov'
		upload_to = remake["footages"][0]["raw_video_s3_key"]
		s3_key = s3_upload(file_to_upload, upload_to, :private)
		assert_equal(true, S3_HOMAGE_BUCKET.objects[upload_to].exists?)

		@delete_object_from_s3 = upload_to

		processed_s3_key = remake["footages"][0]["processed_video_s3_key"]
		assert_equal(false, S3_HOMAGE_BUCKET.objects[processed_s3_key].exists?)

		# run process
		post '/process', {:remake_id => remake["_id"].to_s, :scene_id => "1", :take_id => remake["footages"][0]["take_id"]}

		assert_equal(200, last_response.status)
		assert_equal(true, S3_HOMAGE_BUCKET.objects[processed_s3_key].exists?)

		remake = REMAKES.find_one(remake["_id"])
		assert_equal(FootageStatus::Ready, remake["footages"][0]["status"])
		# tests: db status changed; uploaded to s3


		# delete document

		# delete s3
	end

	def create_remake
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

		return REMAKES.find_one(remake_id)
	end

	def test_error_directory_exists
	end

	def test_error_Errno_ENOENT
	end

	def test_foreground_not_needed_360
	end

	def test_foreground_not_needed_720
	end

	def test_foreground_not_needed_480
	end


	def teardown
		if @delete_remake_from_mongo then
			REMAKES.remove({_id:@delete_remake_from_mongo})
			remake = REMAKES.find_one(@delete_remake_from_mongo)
			assert_nil(remake)
		end
		if @delete_object_from_s3 then
			assert_equal(true, S3_HOMAGE_BUCKET.objects[@delete_object_from_s3].exists?)
			s3_object_folder_to_delete = File.dirname(@delete_object_from_s3)
			S3_HOMAGE_BUCKET.objects.with_prefix(s3_object_folder_to_delete).delete_all
			assert_equal(false, S3_HOMAGE_BUCKET.objects[@delete_object_from_s3].exists?)
		end
	end
end