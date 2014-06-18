require 'set'
require 'fileutils'
require 'mini_exiftool'


# Variables
ffmpeg_path = "C:/Development/ffmpeg/ffmpeg-20131202-git-e3d7a39-win64-static/bin/ffmpeg.exe"
xml_path = "C:/Development/Algo/params.xml"#contour_path.sub(/[^.]+\z/,"xml")
algo_path = "C:/Development/Algo/v-14-06-15/UniformMattingCA.exe"


puts "Enter Folder Full Path: "
folder_input = gets
# Removing unwanted charachters form the input and switching from backslash to slash
folder_chomped = folder_input.tr('"', '').chomp
folder = folder_chomped.gsub /\\+/, '/'
folder = folder + "/"
puts folder

# puts "Enter full path to contour: "
# contour_input = gets
# contour_chomped = contour_input.tr('"', '').chomp
# contour_path = contour_chomped.gsub /\\+/, '/'
# puts contour_path



supported_extensions = Set.new [".mov", ".MOV", ".mp4", ".MP4", ".wmv", ".WMV"]

Dir.foreach(folder) do |file|
	extension = File.extname(file)
	if (supported_extensions.include?(extension))
		puts file

		video_path = folder + file
		video_metadata = MiniExiftool.new(video_path)
		frame_rate = video_metadata.VideoFrameRate.round.to_s

		# Creating images from the video
		images_fodler = folder + "Images/"
		FileUtils.mkdir images_fodler
		ffmpeg_command = ffmpeg_path + ' -i "' + video_path + '" -r ' + frame_rate + ' -q:v 1 "' + images_fodler + 'Image-%4d.jpg"'
		puts "*** Video to images *** \n" + ffmpeg_command
		system(ffmpeg_command)

		# Running the foreground extraction algorithm
		contour_path = folder + File.basename(file, ".*" ) + ".ctr"
		#roi_path = folder + File.basename(file, ".*" ) + ".ebox"
		#roi_path = "C:/Development/Algo/Full.ebox"
		first_image_path = images_fodler + "Image-0001.jpg"
		output_path = folder + File.basename(file, ".*" ) + "-Foreground" + ".avi"
		# Assigning the flip switch if this video is upside down
		flip_switch = ""
		if video_metadata.Rotation == 180 then
			flip_switch = "-Flip"
		end
		algo_command = algo_path + ' -CA "' + xml_path + '" "' + contour_path + '" ' + flip_switch + ' "' + first_image_path + '" -avic -r' + frame_rate + ' -mp4 "' + output_path + '"'
		puts "*** Running Algo *** \n" + algo_command 
		system(algo_command)

		# Converting the large avi file to a small mp4 file
		mp4_path = output_path.chomp(File.extname(output_path)) + ".mp4"
		convert_command = ffmpeg_path + ' -i "' + output_path + '" -vcodec mpeg4 -b:v 1200k "' + mp4_path + '"'
		puts "*** avi to mp4 *** \n" + convert_command
		system(convert_command)
	
		# Deleting the big avi file
		puts "*** Deleting avi... ***"
		FileUtils.remove_file(output_path)

		# Deleting the images directory
		puts "*** Deleting Images... ***"
		FileUtils.remove_dir(images_fodler)
	end
end