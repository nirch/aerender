require '../utils/aws/homage_aws'

env = ARGV[0]
folder_key = ARGV[1]

if env == "prod"
	s3 = HomageAWS::HomageS3.production
elsif env == "test"
	s3 = HomageAWS::HomageS3.test
else
	puts '"prod" or "test" in environment'
	exit
end

s3_objects = s3.bucket.objects.with_prefix(folder_key)
for s3_object in s3_objects do
	puts s3_object.key
end