require '../queue/AVUtils'
require '../queue/Video'


AVUtils.ffmpeg_binary = '/Users/tomer/Documents/ffmpeg/ffmpeg'
video = AVUtils::Video.new('/Users/tomer/Desktop/Delete/crop_and_resize/720.mp4')
puts video.resolution
puts video.frame_rate
puts video.upside_down?
puts video.audio_channel?

resized_video = video.resize(640,360,'/Users/tomer/Desktop/Delete/crop_and_resize/720_resize.mp4')
puts resized_video.resolution
puts resized_video.frame_rate
puts resized_video.upside_down?
puts resized_video.audio_channel?

