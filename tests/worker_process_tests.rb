#require File.expand_path '../test_helper.rb', __FILE__
require File.expand_path '../worker_test_helper.rb', __FILE__
require '../video_process_worker'

class TestWorkerProcess < MiniTest::Unit::TestCase
	include Rack::Test::Methods

	REMAKES = DB.collection("Remakes")
	#USERS = DB.collection("Users")
	#STORIES = DB.collection("Stories")


	def app
		Sinatra::Application
	end

	def setup
	end


	def test_error_directory_exists
	end

	def test_error_Errno_ENOENT
	end

	def test_foreground_not_needed_360
	end

	def test_foreground_not_needed_720
	end

	def test_foreground_not_needed_480
	end


	def teardown
	end
end