require 'minitest/autorun'
#require 'test/unit'
require 'mongo'

class TestNewMongoDriver < MiniTest::Test
#Test::Unit::TestCase
 
	def setup
		Mongo::Logger.logger.level = Logger::WARN
		@client = Mongo::Client.new(['paulo.mongohq.com:10008'], :database => 'Homage', :user => 'Homage', :password => 'homageIt12', :connect => :direct)
		#@client = Mongo::Client.new(['mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage'])
	end

	def test_existing_collection
		stories = @client[:Stories]
		assert remakes.count > 0
	end

	def test_existing_collection
		collection = @client[:bla]
		assert collection.count == 0
	end

	def test_find
		stories = @client[:Stories]
		level_zero_stories = stories.find({level:0})
		assert level_zero_stories.count > 0
	end

	def test_find_one
		stories = @client[:Stories]
		story_id = BSON::ObjectId.from_string('52ee613cab557ec484000021') # "The Oscars" story
		story_name = stories.find({_id:story_id}).each.next["name"]
		assert story_name == "The Oscars"
	end

	def test_count
		stories = @client[:Stories]
		count = stories.count({level:0})
		assert count > 0
	end

	def test_update
		remakes = @client["Remakes"]
		remake_id = BSON::ObjectId.from_string('53da334cb8fef16ba100000b') # Test remake
		result = remakes.update_one({_id: remake_id}, {"$set" => {status: 999}})
		assert result.n == 1
	end

	def test_update_array
		remakes = @client["Remakes"]
		remake_id = BSON::ObjectId.from_string('53da334cb8fef16ba100000b') # Test remake
		result = remakes.update_one({_id: remake_id, "footages.scene_id" => 2}, {"$set" => {"footages.$.status" => 999}})
		assert result.n == 1
	end

	def test_options
		puts @client.inspect
	end

  	def teardown
  	end
end
