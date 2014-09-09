require_relative 'Video'
require 'logger'
require 'streamio-ffmpeg'

module AVUtils

  # FFMPEG logs information about its progress when it's transcoding.
  # Jack in your own logger through this method if you wish to.
  #
  # @param [Logger] log your own logger
  # @return [Logger] the logger you set
  def self.logger=(log)
    @logger = log
    FFMPEG.logger = log
  end

  # Get FFMPEG logger.
  #
  # @return [Logger]
  def self.logger
    return @logger if @logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @logger = logger
  end

  # Set the path of the ffmpeg binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/ffmpeg
  #
  # @param [String] path to the ffmpeg binary
  # @return [String] the path you set
  def self.ffmpeg_binary=(bin)
    @ffmpeg_binary = bin
    FFMPEG.ffmpeg_binary = bin
  end

  # Get the path to the ffmpeg binary, defaulting to 'ffmpeg'
  #
  # @return [String] the path to the ffmpeg binary
  def self.ffmpeg_binary
    @ffmpeg_binary || 'ffmpeg'
  end

  # Set the path of the algo binary.
  #
  # @param [String] path to the algo binary
  # @return [String] the path you set
  def self.algo_binary=(bin)
    @algo_binary = bin
  end

  # Get the path to the algo binary, defaulting to 'UniformBackground.exe'
  #
  # @return [String] the path to the algo binary
  def self.algo_binary
    @algo_binary || 'UniformBackground.exe'
  end

  # Set the path of the algo params xml.
  #
  # @param [String] path to the algo params xml
  # @return [String] the path you set
  def self.algo_params=(params)
    @algo_params = params
  end

  # Get the path to the algo params xml, defaulting to 'params.xml'
  #
  # @return [String] the path to the algo params xml
  def self.algo_params
    @algo_params || 'params.xml'
  end

  # Set the path of the aerender binary.
  #
  # @param [String] path to the aerender binary
  # @return [String] the path you set
  def self.aerender_binary=(bin)
    @aerender_binary = bin
  end

  # Get the path to the aerender binary, defaulting to 'aerender.exe'
  #
  # @return [String] the path to the aerender binary
  def self.aerender_binary
    @aerender_binary || 'aerender.exe'
  end
end