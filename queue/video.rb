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

		def audio_channel?
			return true if @metadata.AudioChannels
			false
		end

		def resize(width, height, destination)
			resize_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vf scale=' + width.to_s + ':' + height.to_s + ' -strict -2 -y "' + destination + '"'
			puts "resize video command: " + resize_command
			system(resize_command)
			return AVUtils::Video.new(destination)
			#raw_video_file_path = resized_video_path
		end

	end
end