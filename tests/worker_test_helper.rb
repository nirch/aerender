ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'mongo'
require 'aws-sdk'


DB = Mongo::MongoClient.from_uri("mongodb://Homage:homageIt12@paulo.mongohq.com:10008/Homage").db()

# AWS Connection
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)
s3 = AWS::S3.new
S3_HOMAGE_BUCKET = s3.buckets['homageapp']

def s3_upload(file_path, s3_key, acl, content_type=nil)
	s3_object = S3_HOMAGE_BUCKET.objects[s3_key]
	#logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
	file = File.new(file_path)
	s3_object.write(file, {:acl => acl, :content_type => content_type})
	file.close
	#puts "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s
	return s3_object
end
