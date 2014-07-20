class ProcessVideo
	attr_reader :raw_video_path, :working_folder, :contour_path

	def initialize(raw_video_path, contour_path, working_folder)
		raise Errno::ENOENT, "the file '#{raw_video_path}' does not exist" unless File.exists?(raw_video_path)
		raise Errno::ENOENT, "the directory '#{working_folder}' does not exist" unless File.directory?(working_folder)
		raise Errno::ENOENT, "the file '#{contour_path}' does not exist" unless File.exists?(contour_path)

		@raw_video_path = raw_video_path
		@contour_path = contour_path
		@working_folder = working_folder
	end

	def process(processed_vide_path)

	end
end