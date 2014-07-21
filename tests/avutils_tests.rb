require '../queue/AVUtils'
require '../queue/Video'

require "test/unit"

class TestAVUtils < Test::Unit::TestCase
 
	def setup
		AVUtils.ffmpeg_binary = '/Users/tomer/Documents/ffmpeg/ffmpeg'
		@delete_files = Array.new
		@delete_folder = nil	
	end

	def test_metadata_resolution
		video_720 = AVUtils::Video.new(File.expand_path('resources/720.mp4'))
		video_480 = AVUtils::Video.new(File.expand_path('resources/480.mov'))

		assert_equal("1280x720", video_720.resolution)
		assert_equal("640x480", video_480.resolution)		
	end

	def test_metadata_upside_down
		video_not_upside_down = AVUtils::Video.new(File.expand_path('resources/720.mp4'))
		video_upside_down = AVUtils::Video.new(File.expand_path('resources/upside_down.mov'))
		assert_equal(false, video_not_upside_down.upside_down?)
		assert_equal(true, video_upside_down.upside_down?)
	end
 
 	def test_audio
 		video_has_audio = AVUtils::Video.new(File.expand_path('resources/720.mp4'))
 		video_no_audio = AVUtils::Video.new(File.expand_path('resources/no_audio.mp4'))
		assert_equal(true, video_has_audio.audio?)
		assert_equal(false, video_no_audio.audio?)
 	end

 	def test_frame_rate
 	end

 	def test_resize_720_to_360
		video_720 = AVUtils::Video.new(File.expand_path('resources/720.mp4'))

		resize_destination = File.expand_path('resources/360_from_720.mp4')
		@delete_files.push(resize_destination)

 		resized_360_video = video_720.resize(640,360,resize_destination)

 		assert_equal("640x360", resized_360_video.resolution)
 	end

 	def test_resize_720_to_360_no_destination
		video_720 = AVUtils::Video.new(File.expand_path('resources/720.mp4'))

 		resized_360_video = video_720.resize(640,360)
 		@delete_files.push(resized_360_video.path)

 		assert_equal("640x360", resized_360_video.resolution)
 		assert_equal(File.expand_path('resources/720-resized.mp4'), resized_360_video.path)
 	end

 	def test_crop_480_to_360
		video_480 = AVUtils::Video.new(File.expand_path('resources/480.mov'))

		crop_destination = File.expand_path('resources/360_from_480.mp4')
		@delete_files.push(crop_destination)

 		cropped_360_video = video_480.crop(640,360,crop_destination)
 		assert_equal("640x360", cropped_360_video.resolution)
 	end

 	def test_crop_480_to_360_no_destination
		video_480 = AVUtils::Video.new(File.expand_path('resources/480.mov'))

 		cropped_360_video = video_480.crop(640,360)		
		@delete_files.push(cropped_360_video.path)

 		assert_equal("640x360", cropped_360_video.resolution)
 		assert_equal(File.expand_path('resources/480-cropped.mp4'), cropped_360_video.path)
 	end

 	def test_video_to_frames
		video_83_frames = AVUtils::Video.new(File.expand_path('resources/upside_down.mov'))
		frame_rate = video_83_frames.frame_rate

		frame_folder = File.expand_path('resources/frames/') + "/"
		FileUtils.mkdir frame_folder
		@delete_folder = frame_folder

		video_83_frames.frames(frame_rate, frame_folder)

		assert_equal(83, Dir[frame_folder  + "**/*"].length)
 	end

 	def test_video_to_frames_no_desination
		video_83_frames = AVUtils::Video.new(File.expand_path('resources/upside_down.mov'))
		frame_rate = video_83_frames.frame_rate

		first_frame_path = video_83_frames.frames(frame_rate)
		frame_folder = File.dirname(first_frame_path)
		@delete_folder = frame_folder

		assert_equal(true, File.directory?(frame_folder))
		assert_equal(83, Dir[frame_folder  + "**/*"].length)
 	end

 	def test_video_transcode
		video = AVUtils::Video.new(File.expand_path('resources/upside_down.mov'))

		transcode_destination = File.expand_path('resources/transcoded.mp4')
		@delete_files.push(transcode_destination)

		transcoded_video = video.transcode("mpeg4", "650", transcode_destination)
		assert_equal(transcoded_video.resolution, video.resolution)
 	end

 	def test_video_transcode_no_destinaion
		video = AVUtils::Video.new(File.expand_path('resources/upside_down.mov'))

		transcoded_video = video.transcode("mpeg4", "650")
		@delete_files.push(transcoded_video.path)

		assert_equal(transcoded_video.resolution, video.resolution)
		assert_equal(File.expand_path('resources/upside_down-transcoded.mp4'), transcoded_video.path)
 	end

 	def test_add_audio
 		video_no_audio = AVUtils::Video.new(File.expand_path('resources/no_audio.mp4'))

 		video_audio_path = File.expand_path('resources/audio.mp4')
 		add_audio_destination = File.expand_path('resources/add_audio.mp4')
 		@delete_files.push(add_audio_destination)

 		add_audio_video = video_no_audio.add_audio(video_audio_path, add_audio_destination)
 		assert_equal(true, add_audio_video.audio?)

 	end

 	def test_add_audio_no_destination
 		#video_audio = AVUtils::Video.new('resources/audio.mp4')
 		video_no_audio = AVUtils::Video.new(File.expand_path('resources/no_audio.mp4'))

 		video_audio_path = File.expand_path('resources/audio.mp4')
 		add_audio_destination = File.expand_path('resources/add_audio.mp4')

 		add_audio_video = video_no_audio.add_audio(video_audio_path)
 		@delete_files.push(add_audio_video.path)

 		assert_equal(true, add_audio_video.audio?)
 		assert_equal(File.expand_path('resources/no_audio-audio.mp4'), add_audio_video.path)
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


# AVUtils.ffmpeg_binary = '/Users/tomer/Documents/ffmpeg/ffmpeg'
# video = AVUtils::Video.new('/Users/tomer/Desktop/Delete/crop_and_resize/720.mp4')
# puts video.resolution
# puts video.frame_rate
# puts video.upside_down?
# puts video.audio_channel?

# resized_video = video.resize(640,360,'/Users/tomer/Desktop/Delete/crop_and_resize/720_resize.mp4')
# puts resized_video.resolution
# puts resized_video.frame_rate
# puts resized_video.upside_down?
# puts resized_video.audio_channel?

