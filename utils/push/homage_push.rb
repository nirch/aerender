require 'houston'
require 'gcm'
require 'homage_push_client'
require 'homage_push_types'

module HomagePush

  # HomagePush logs information about its progress when it's pushing.
  # Jack in your own logger through this method if you wish to.
  #
  # @param [Logger] log your own logger
  # @return [Logger] the logger you set
  def self.logger=(log)
    @logger = log
  end

  # Get HomagePush logger.
  #
  # @return [Logger]
  def self.logger
    return @logger if @logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @logger = logger
  end

  def self.push_video_ready(story, remake, user, push_client)
    message = "Your " + story["name"] + " video is ready!"
    data = {type: HomagePush::VideoReady, remake_id: remake["_id"].to_s, story_id: story["_id"].to_s, title:"Video Ready!"}
    
    push_to_user(user, message, data, push_client)
  end

  def self.push_video_timeout(remake, user, push_client)
    message = "Failed to create your video, open the application and try again"
    data = {type: HomagePush::VideoTimout, remake_id: remake["_id"].to_s, story_id: remake["story_id"].to_s, title:"Video Creation Failed"}

    push_to_user(user, message, data, push_client)
  end

  def self.push_to_user(user, message, data, push_client)
    logger.info "push to user: " + user["_id"].to_s + "; " + message + "; " + data.to_s

    tokens_used = Set.new
    for device in user["devices"] do
      token = device["push_token"] if device["push_token"]
      token = device["android_push_token"] if device["android_push_token"]

      # Checking that not already pushed to this token
      if !tokens_used.include?(token) then
        push_client.push_ios(token, message, data) if device["push_token"]
        push_client.send_android(token, message, data) if device["android_push_token"]
        tokens_used.add(token)
      end
    end
  end

end