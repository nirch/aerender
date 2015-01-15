folder = 'C:/Users/homage/Documents/Data/Backgroud/Objects/*.*'

Dir.glob(folder) do |file|
	extension = File.extname(file)
	basename = File.basename(file)
	if extension != ''
		new_name = File.join File.dirname(file), basename.split('_')[0] + extension
		File.rename(file, new_name)
	end
end
