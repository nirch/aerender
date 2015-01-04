
module HomageAWS
	class HomageS3

		attr_accessor :bucket

		class << self
			def test
				homage_s3 = self.new
				s3 = AWS::S3.new
				homage_s3.bucket = s3.buckets['homagetest']
				homage_s3
			end

			def production
				homage_s3 = self.new
				s3 = AWS::S3.new
				homage_s3.bucket = s3.buckets['homageapp']
				homage_s3
			end
	    end

	    def download(object_key, local_path)
			HomageAWS.logger.info "Downloading file from S3 with key " + object_key
			object = @bucket.objects[object_key]
			File.open(local_path, 'wb') do |file|
		  		object.read do |chunk|
		    		file.write(chunk)
		    	end
		    	file.close
		    end
		  	HomageAWS.logger.info "File downloaded successfully to: " + local_path
		  	return object
	    end

		def upload(file_path, s3_key, acl, content_type=nil, metadata=nil)
			s3_object = @bucket.objects[s3_key]
			HomageAWS.logger.info 'Uploading the file <' + file_path + '> to S3 path <' + s3_object.key + '>'
			s3_object.write(Pathname.new(file_path), {:acl => acl, :content_type => content_type, :metadata => metadata})
			HomageAWS.logger.info "Uploaded successfully to S3, url is: " + s3_object.public_url.to_s
			return s3_object
		end

		def delete(object_key)
			HomageAWS.logger.info "Deleting file from S3 with key " + object_key
			s3_object = @bucket.objects[object_key]
			s3_object.delete			
		end

		def get_object(object_key)
			return @bucket.objects[object_key]
		end
	end
end