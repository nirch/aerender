require '../queue/AVUtils'
require '../queue/Video'

require "test/unit"

class TestVideoProcess < Test::Unit::TestCase
 
	def setup
		AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'
		AVUtils.algo_binary = 'C:/Development/Algo/v-14-07-19/UniformMattingCA.exe'
		AVUtils.algo_params = 'C:/Development/Algo/params.xml'
		@delete_files = Array.new
		@delete_folder = nil	
	end

	def test_process_720_video
	end

	def test_process_480_video
	end

	def test_process_360_right_side_up_audio
		# Creating a new folder for the processing and copying the tested file to there
		process_folder = 'resources/process/'
		FileUtils.mkdir process_folder
		FileUtils.copy_file('resources/360_right_side_up_audio.mov', 'resources/process/360_right_side_up_audio.mov')
		FileUtils.copy_file('resources/360_right_side_up_audio.ctr', 'resources/process/360_right_side_up_audio.ctr')
		@delete_folder = process_folder

		video = AVUtils::Video.new('resources/process/360_right_side_up_audio.mov')
		processed_video = video.process('resources/process/360_right_side_up_audio.ctr')

		assert_equal('360_right_side_up_audio-foreground-transcoded-audio.mp4', File.basename(processed_video.path))
		assert_equal(true, processed_video.audio?)
		assert_equal("640x360", processed_video.resolution)
		assert_equal(false, processed_video.upside_down?)		
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