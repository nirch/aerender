
module AVUtils
  # Set the path of the ffmpeg binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/ffmpeg
  #
  # @param [String] path to the ffmpeg binary
  # @return [String] the path you set
  def self.ffmpeg_binary=(bin)
    @ffmpeg_binary = bin
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
  # @return [String] the path to the ffmpeg binary
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
end