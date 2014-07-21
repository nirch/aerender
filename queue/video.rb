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

		def resize(width, height, destination=nil)
			destination = File.join(File.dirname(@path), File.basename(@path,".*") + "-resized.mp4") unless destination

			# ffmpeg -i "resources/720.mp4" -vf scale=640:360 -y "resources/360_from_720.mp4"
			resize_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vf scale=' + width.to_s + ':' + height.to_s + ' -strict -2 -y "' + destination + '"'
			puts "resize video command: " + resize_command
			system(resize_command)
			return AVUtils::Video.new(destination)
		end

		def crop(width, height, destination=nil)
			destination = File.join(File.dirname(@path), File.basename(@path,".*") + "-cropped.mp4") unless destination

			# ffmpeg -i "resources/480.mov" -vf crop=640:360 -y "resources/360_from_480.mp4"
			crop_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vf crop=' + width.to_s + ':' + height.to_s + ' -strict -2 -y "' + destination + '"'
			puts "crop video command: " + crop_command
			system(crop_command)
			return AVUtils::Video.new(destination)
		end

		def frames(frame_rate, destination_folder=nil)
			destination_folder = File.dirname(@path) + "/Images/" unless destination_folder
			FileUtils.mkdir destination_folder unless File.directory?(destination_folder)

			# ffmpeg -i "resources/upside_down.mov" -r 25 -q:v 1 "resources/frames/Image-%4d.jpg"
			frames_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -r ' + frame_rate.to_s + ' -q:v 1 "' + destination_folder + 'Image-%4d.jpg"'
			puts "video frame command: " + frames_command
			system(frames_command)
			return destination_folder + "Image-0001.jpg"
		end

		def transcode(codec, bitrate, destination=nil)
			destination = File.join(File.dirname(@path), File.basename(@path,".*") + "-transcoded.mp4") unless destination

			# ffmpeg -i "resources/upside_down.mov" -vcodec mpeg4 -b:v 1200k  -y "resources/transcoded.mp4"
			transcode_command = AVUtils.ffmpeg_binary + ' -i "' + @path + '" -vcodec ' + codec + ' -b:v ' + bitrate.to_s + 'k -strict -2 -y "' + destination + '"'
			puts "transcode command: " + transcode_command
			system(transcode_command)
			return AVUtils::Video.new(destination)
		end

		def add_audio(video_with_audio_path, destination=nil)
			destination = File.join(File.dirname(@path), File.basename(@path,".*") + "-audio.mp4") unless destination

			# fmpeg -i "resources/audio.mp4" -i "resources/no_audio.mp4" -c copy -map 0:1 -map 1:0 -strict -2 -y "resources/no_audio-audio.mp4"
			add_audio_command = AVUtils.ffmpeg_binary + ' -i "' + video_with_audio_path + '" -i "' + @path + '" -c copy -map 0:1 -map 1:0 -strict -2 -y "' + destination + '"'
			puts "add audio command: " + add_audio_command
			system(add_audio_command)
			return AVUtils::Video.new(destination)
		end

		def process(contour_path, destination=nil)
			raise Errno::ENOENT, "the directory '#{working_folder}' does not exist" unless File.directory?(working_folder)
			raise Errno::ENOENT, "the file '#{contour_path}' does not exist" unless File.exists?(contour_path)

			raw_video = self
			video_to_process = self

			# Resizing/Cropping the video to 360p (640x360) if needed
			if video_to_process.resolution == "1280x720" then
				video_to_process = video_to_process.resize(640, 360)
			elsif video_to_process.resolution == "640x480" then
				video_to_process = video_to_process.crop(640, 360)
			end

			# Creating all the frames out of this video (used later by the algo)
			frame_rate = video_to_process.frame_rate
			first_frame_path = video_to_process.frames(frame_rate)

			# Setting the flip_switch parameter if the raw video is upside down
			video_to_process.upside_down? ? flip_switch = "-Flip" : flip_switch = "" 

			destination = File.join(File.dirname(@path), File.basename(@path,".*") + "-foreground.avi") unless destination

			# Running the foreground extraction algorithm
			algo_command = AVUtils.algo_binary + ' -CA "' + AVUtils.algo_params + '" "' + contour_path + '" ' + flip_switch + ' "' + first_frame_path + '" -avic -r' + frame_rate + ' -mp4 "' + destination + '"'
			puts "algo command: " + algo_command 
			system(algo_command)
			video_to_process = AVUtils::Video.new(destination)

			# Transcoding the large AVI file to a small mp4 file
			video_to_process = video_to_process.transcode("mpeg4", "1200")

			# Adding the audio from the raw video (only if the raw video has audio)
			video_to_process = video_to_process.add_audio(raw_video.path) unless !raw_video.audio?

			return video_to_process
		end


	end
end