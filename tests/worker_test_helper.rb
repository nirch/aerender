ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db()
