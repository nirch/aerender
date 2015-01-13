require 'fileutils'
require 'mini_exiftool'

folder = 'C:/Development/Homage/Background/Try'
background_ca_path = 'C:\Development\Homage\Background\Binary\UnBackgroundCAD.exe'
params_path = 'C:\Development\Algo\params.xml'

output_folder = File.join folder, 'Output'#'C:/Development/Homage/Background/Runtest/Output'
junk_folder = File.join folder, 'Junk'#'C:/Development/Homage/Background/Runtest/Junk'

FileUtils.mkdir output_folder unless File.directory?(output_folder)
FileUtils.mkdir junk_folder unless File.directory?(junk_folder)

folder_jpg = folder + '/*.jpg'

Dir.glob(folder_jpg) do |file|
	puts "checking: " + file
	thumbnail_path = file
	video_path = file.sub(/[^.]+\z/,"mov")
	contour_path = file.sub(/[^.]+\z/,"ctr")
	junk_path = File.join junk_folder, File.basename(file.sub(/[^.]+\z/,"txt"))

	video_metadata = MiniExiftool.new(video_path)

	flip_switch = ""
	if video_metadata.Rotation == 180 then
		flip_switch = "-Flip"
	end

	background_command = background_ca_path + ' -P' + params_path + ' ' + contour_path + ' ' + flip_switch + ' ' + thumbnail_path + ' ' + junk_path

	# Running the command
	output = IO.popen(background_command).readlines
	background_state = output[output.length-1].split(': ')[1].chomp
	puts background_state

	output_path = File.join output_folder, File.basename(thumbnail_path, ".jpg") + '-' +background_state + ".jpg"
	FileUtils.copy thumbnail_path, output_path
end
