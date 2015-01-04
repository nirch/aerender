require '../utils/aws/homage_aws'
require "test/unit"
require "FileUtils"

class TestHomageS3 < Test::Unit::TestCase
	def setup
		@homage_s3 = HomageAWS::HomageS3.test
		@delete_files = Array.new
		@delete_folder = nil	
	end

	def test_download
		download_key = 'test/result1.mp4'
		download_destination = 'resources/download.mp4'

		assert_equal false, File.exists?(download_destination)
		@homage_s3.download download_key, 'resources/download.mp4'
		assert_equal true, File.exists?(download_destination)

		@delete_files.push(download_destination)
	end

	def test_upload
		upload_file = 'resources/upside_down.mov'
		upload_s3_destination = 'test/upload.mp4'

		assert_equal false, @homage_s3.get_object(upload_s3_destination).exists?

		# Uploading the Object
		@homage_s3.upload upload_file, upload_s3_destination, :public_read
		assert_equal true, @homage_s3.get_object(upload_s3_destination).exists?

		# Deleting the Object
		@homage_s3.delete upload_s3_destination
		assert_equal false, @homage_s3.get_object(upload_s3_destination).exists?		
	end

	def test_metadata
		# Uploading a video with metadata
		upload_file = 'resources/upside_down.mov'
		upload_s3_destination = 'test/upload.mp4'
		@homage_s3.upload upload_file, upload_s3_destination, :public_read, nil, {"test" => "bla"}

		object = @homage_s3.get_object(upload_s3_destination)
		assert_equal 'bla', object.metadata['test']

		# Deleting the Object
		@homage_s3.delete upload_s3_destination
		assert_equal false, @homage_s3.get_object(upload_s3_destination).exists?				
	end

	def teardown
  		for file_to_delete in @delete_files do
  			FileUtils.remove_file(file_to_delete) if File.exists?(file_to_delete)
  		end

  		if @delete_folder then
  			FileUtils.remove_dir(@delete_folder) if File.directory?(@delete_folder)
  		end
  	end
end