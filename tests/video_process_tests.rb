require '../queue/AVUtils'
require '../queue/Video'

require "test/unit"

class TestAVUtils < Test::Unit::TestCase
 
	def setup
		AVUtils.ffmpeg_binary = '/Users/tomer/Documents/ffmpeg/ffmpeg'
		@delete_files = Array.new
		@delete_folder = nil	
	end

	def test_process_720_video
	end

	def test_process_480_video
	end

	def test_process_360_video
	end

	def test_process_360_upside_down_video
	end

	def test_process_360_no_audio_video
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