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
	set :aerenderPath, "C:/Program Files/Adobe/Adobe After Effects CC/Support Files/aerender.exe"
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
	redirect back
end

post '/render' do
	projectPath = settings.aeProjectsFolder + params[:template_folder] + "/" + params[:template_project]
	outputPath = settings.outputFolder +  params[:output] + ".mp4"
	aerenderCommandLine = '"' + settings.aerenderPath + '"' + ' -project "' + projectPath + '"' + ' -rqindex 1 -output "' + outputPath + '"'
	puts "areder command line: #{aerenderCommandLine}"

	response = system(aerenderCommandLine)

	redirect "/download/" + params[:output] + ".mp4"
end

get '/download/:filename' do
	downloadPath = settings.outputFolder + params[:filename]
	puts "download file path: #{downloadPath}"
	send_file downloadPath
end

