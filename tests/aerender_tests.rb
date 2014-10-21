require '../video/AVUtils'
require '../video/Video'

require "test/unit"

class TestAERender < Test::Unit::TestCase
 
	def setup
		AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'
		#AVUtils.algo_binary = 'C:/Development/Algo/v-14-07-19/UniformMattingCA.exe'
		#AVUtils.algo_params = 'C:/Development/Algo/params.xml'
		AVUtils.aerender_binary = "C:/Program Files/Adobe/Adobe After Effects CC/Support Files/aerender.exe"
		@delete_files = Array.new
		#@delete_folder = nil	
	end

	def test_aerender
		video = AVUtils::Video.aerender("C:/Users/Channes/Documents/AE Projects/Big Bro/bigbro2.aep", "C:/Development/Homage/After/Ouput/test.mp4")

		assert video
		assert_equal('test.mp4', File.basename(video.path))

		@delete_files.push(video.path)
	end

	def test_aerender_error_aebinary_missing
	end

	def test_aerender_error_project_missing
	end

	def test_aerender_error_destination_folder_missing
	end


	def teardown
  		for file_to_delete in @delete_files do
  			FileUtils.remove_file(file_to_delete) if File.exists?(file_to_delete)
  		end
  	end
end