require 'set'
require 'fileutils'
require 'mongo'


DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db()
PROD_DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@troup.mongohq.com:10057/Homage_Prod").db()



folder = ARGV[0]

supported_extensions = Set.new [".mov", ".MOV", ".mp4", ".MP4", ".wmv", ".WMV"]

Dir.foreach(folder) do |file|
	extension = File.extname(file)
	if (supported_extensions.include?(extension))
		remake_id = BSON::ObjectId.from_string(file.to_s.partition("_")[0])
		scene_id = file.to_s.split("_").last.split(".")[0].to_i

		remake = PROD_DB.collection("Remakes").find_one(remake_id)
		remake = DB.collection("Remakes").find_one(remake_id) if !remake
		story = DB.collection("Stories").find_one(remake["story_id"])

		puts "story_id=" + remake["story_id"].to_s + "; remake_id=" + remake_id.to_s + "; scene_id=" + scene_id.to_s if !story["scenes"][scene_id - 1]["contours"]["360"]["contour"]

		old_contour = story["scenes"][scene_id - 1]["contours"]["360"]["contour"].split("/").last
		new_contour = old_contour.split(".")[0] + "-face" + ".ctr"
		new_contour_path = folder + '/Face/' + new_contour

		new_folder = folder + '/New/'
		new_video_path = new_folder + file
		new_contour_video_path = new_video_path.sub(/[^.]+\z/,"ctr")

		FileUtils.copy(folder + "/" + file, new_video_path)
		FileUtils.copy(new_contour_path, new_contour_video_path)

		#puts new_contour

		#puts File.exists?(folder + '/Face/' + new_contour) ? "Yes" : "No"

		#remake["story_id"]
	end
end