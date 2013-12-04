#encoding: utf-8
require 'sinatra'
require 'mongo'
require 'uri'
require 'json'
require 'fileutils'

#include Mongo

configure do
	# Setting db connection param
	db_connection = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage")
	set :db, db_connection.db()

	# Setting folders param
	set :aeProjectsFolder, "C:/Users/Administrator/Documents/AE Projects/"
	set :aerenderPath, "C:/Program Files/Adobe/Adobe After Effects CS6/Support Files/aerender.exe"
	set :outputFolder, "C:/Users/Administrator/Documents/AE Output/"
end

def get_templates
	collection = settings.db.collection("Templates")
	docs = collection.find.sort({id: 1});
	parsed_array = Array.new
	for doc in docs do
		parsed_doc = JSON.parse(doc.to_json)
		parsed_array.push(parsed_doc)
	end
	templates = parsed_array
end

get '/templates' do
	@templates = get_templates
	erb :templates
end

get '/templates/:id' do
	# Getting the the template that matches the id in the url
	templates_collection = settings.db.collection("Templates")
	template_doc_json = templates_collection.find_one({id:params[:id].to_i}).to_json
	@template = JSON.parse(template_doc_json)
	erb :template
end

post '/upload' do
	source = params[:file][:tempfile]
	destination = settings.aeProjectsFolder + params[:template_folder] + "/(Footage)/" + params[:segment_file]
	puts destination
	FileUtils.copy(source.path, destination)

	'Uploaded!'
	#redirect back
end

post '/update_text' do
	dynamic_text_path = settings.aeProjectsFolder + params[:template_folder] + "/" + params[:dynamic_text_file]
	dynamic_text = params[:dynamic_text]
	file_contents = "var Text = ['#{dynamic_text}'];"

	dynamic_text_file = File.new(dynamic_text_path, "w")
    dynamic_text_file.puts(file_contents)
    dynamic_text_file.close

    'Text updated!'
    #redirect back
end

post '/render' do

	projectPath = settings.aeProjectsFolder + params[:template_folder] + "/" + params[:template_project]
	outputPath = settings.outputFolder +  params[:output] + ".mp4"
	aerenderCommandLine = '"' + settings.aerenderPath + '"' + ' -project "' + projectPath + '"' + ' -rqindex 1 -output "' + outputPath + '"'
	puts "areder command line: #{aerenderCommandLine}"

	#Thread.new{
		system(aerenderCommandLine)
	#}

	#redirect_to = "/download/" + params[:output] + ".mp4"
	#erb "Wait a minute, and click this link: <a href=" + redirect_to + ">" +  params[:output] + "</a>"
end

get '/download/:filename' do
	downloadPath = settings.outputFolder + params[:filename]
	puts "download file path: #{downloadPath}"
	send_file downloadPath #, :type => 'video/mp4', :disposition => 'inline'
end


################################
# Foreground extraction script #
################################

get '/foreground' do
	form = '<form action="/foreground" method="post" enctype="multipart/form-data"> <input type="file" accept="video/*" name="file"> <input type="submit" value="Foreground!"> </form>'
	erb form
end

post '/foreground' do

	foreground_folder = "C:/Users/Administrator/Documents/Foreground Extraction/"

	# Copying the file locally
	source = params[:file][:tempfile]
	folder = File.basename( params[:file][:filename], ".*" )
	destination_folder = foreground_folder + folder + "/"
	FileUtils.mkdir destination_folder
	destination = destination_folder + params[:file][:filename]
	FileUtils.copy(source.path, destination)
	puts "File copied to: " + destination

	# Creating images from the video
	ffmpeg_path = "C:/Development/ffmpeg/ffmpeg-20131202-git-e3d7a39-win64-static/bin/ffmpeg.exe"
	images_fodler = destination_folder + "Images/"
	FileUtils.mkdir images_fodler
	ffmpeg_command = ffmpeg_path + ' -i "' + destination + '" "' + images_fodler + 'Image-%4d.jpg"'
	puts ffmpeg_command
	system(ffmpeg_command)

	# Running the foreground extraction algorithm
	algo_path = "C:/Development/Algo/v-13-12-01/UniformMattingCA.exe"
	mask_path = "C:/Development/Algo/v-13-12-01/mask-m.bmp"
	first_image_path = images_fodler + "Image-0001.jpg"
	output_path = destination_folder + "Foreground-" + folder + ".avi"
	algo_command = algo_path + ' "' + mask_path + '" "' + first_image_path + '" "' + output_path + '"'
	puts algo_command 
	system(algo_command)

end


