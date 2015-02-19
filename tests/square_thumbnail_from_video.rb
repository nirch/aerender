require_relative '../video/AVUtils'

# Variables
AVUtils.ffmpeg_binary = 'C:/Development/FFmpeg/bin/ffmpeg.exe'

folder_input = ARGV[0]
# Removing unwanted charachters form the input and switching from backslash to slash
folder_chomped = folder_input.tr('"', '').chomp
folder = folder_chomped.gsub /\\+/, '/'
folder = folder + "/*.mov" 

Dir.glob(folder) do |file|
	video = AVUtils::Video.new(file)
	destination = File.join(File.dirname(file), File.basename(file,".*") + ".jpg")

	if video.resolution == "640x480" then
		thumbnail_command = AVUtils.ffmpeg_binary + ' -ss 0 -i "' + file + '" -vf crop=480:480 -frames:v 1 -y ' + '"' + destination + '"'
		puts thumbnail_command
		system(thumbnail_command)
	else
		puts video.resolution + " for video " + file
	end

	#thumbnail_command = AVUtils.ffmpeg_binary + ' -ss ' + time.to_s + ' -i "' + @path + '" -frames:v 1 -y ' + '"' + destination + '"'
	#		AVUtils.logger.info "thumbnail command: " + thumbnail_command
	#		system(thumbnail_command)
end