require 'mini_exiftool'

module AVUtils
	class Video
		attr_reader :path
		@metadata
		@@exiftool_semaphore = Mutex.new

		def initialize(path)
			raise Errno::ENOENT, "the file '#{path}' does not exist" unless File.exists?(path)

			@path = path
		
			# Protecting the call to an outside process with a mutex
			@@exiftool_semaphore.synchronize{
				@metadata = MiniExiftool.new(@path)
			}
		end

		def resolution
			return @metadata.ImageSize
		end

		def frame_rate
			return @metadata.VideoFrameRate.round.to_s
		end

		def upside_down?
			return true if @metadata.Rotation == 180
			false
		end

		def audio?
			return true if @metadata.AudioChannels
			false
		end

		def resize(width, height, destination)
			# ffmpeg -i "resources/720.mp4" -vf scale=640:360 -y "resources/360_from_720.mp4"
			resize_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vf scale=' + width.to_s + ':' + height.to_s + ' -strict -2 -y "' + destination + '"'
			puts "resize video command: " + resize_command
			system(resize_command)
			return AVUtils::Video.new(destination)
		end

		def crop(width, height, destination)
			# ffmpeg -i "resources/480.mov" -vf crop=640:360 -y "resources/360_from_480.mp4"
			crop_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vf crop=' + width.to_s + ':' + height.to_s + ' -strict -2 -y "' + destination + '"'
			puts "crop video command: " + crop_command
			system(crop_command)
			return AVUtils::Video.new(destination)
		end

		def frames(frame_rate, destination_folder)
			# ffmpeg -i "resources/upside_down.mov" -r 25 -q:v 1 "resources/frames/Image-%4d.jpg"
			frames_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -r ' + frame_rate.to_s + ' -q:v 1 "' + destination_folder + 'Image-%4d.jpg"'
			puts "video frame command: " + frames_command
			system(frames_command)
			return true
		end

		def transcode(codec, bitrate, destination)
			# ffmpeg -i "resources/upside_down.mov" -vcodec mpeg4 -b:v 1200k  -y "resources/transcoded.mp4"
			transcode_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vcodec ' + codec + ' -b:v ' + bitrate.to_s + 'k -strict -2 -y "' + destination + '"'
			puts "transcode command: " + transcode_command
			system(transcode_command)
			return AVUtils::Video.new(destination)
		end

		def add_audio(video_with_audio_path, destination)
			add_audio_command = AVUtils.ffmpeg_binary + ' -i "' + video_with_audio_path + '" -i "' + @path + '" -c copy -map 0:1 -map 1:0 -strict -2 -y "' + destination + '"'
			puts "add audio command: " + add_audio_command
			system(add_audio_command)
			return AVUtils::Video.new(destination)
		end
	end
end