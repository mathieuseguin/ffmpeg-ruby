require 'rubygems'
require 'ffmpeg'
require 'RMagick'

# These times are in seconds
times = [2.5, 2.7, 3.0, 3.1, 3.2, 60, 70, 120000].reverse

def two_decimals(val)
  return nil if val.nil?
  ((val * 100.0).to_i/100.0)
end

video = FFMPEG::InputFormat.new('some_movie_longer_than_70_seconds_would_be_nice.mov')
stream = video.first_video_stream
image_list = Magick::ImageList.new



while !times.nil? do
  # get initial desired seek_time into array
  seek_times = [two_decimals(times.pop)]
  
  # all done if no times left!
  break if seek_times.first.nil?
  
  # get the range of display timesstamps for the keyframe 
  # before and after the first seek_time, plus the first keyframe
  # in the range
  frame_b_pts = two_decimals(stream.seek(seek_times.first, 0))
  current_frame, frame_a_pts_big = stream.seek_backwards_and_decode_frame(seek_times.first)
  frame_a_pts = two_decimals(frame_a_pts_big)

  # if seek time past end of stream frame_b_pts
  # should be negative and we're all done!
  break if frame_b_pts <= 0.0
  
  # add other times that fit within this range
  # don't want to waste time decoding a series of frames
  # if other times fall in this range
  next_time = two_decimals(times.last)
  while !next_time.nil? && next_time <= frame_b_pts do
    seek_times << two_decimals(times.pop)
    next_time = two_decimals(times.last)
  end
  seek_times.reverse!
  
  current_seek_time = seek_times.pop
  
  # see if the first keyframe is the one!
  if current_seek_time <= frame_a_pts_big
    image_list.from_blob(frame.to_ppm)
    current_seek_time = seek_times.pop
  end
  
  # if first frame was the one and no more times 
  # left, get out of this loop
  break if current_seek_time.nil?
  
  # loop through and decode each frame beginning
  # after keyframe a
  stream.decode_frame do |frame, pts, dts, flags|
    short_dts = two_decimals(dts)
    
    # break from this loop if no more times to
    # grab for this range
    break if current_seek_time.nil?
    
    # if this frame is past the range
    # grab frame and exit this loop
    # (using greater than logic since not sure
    # of any float funny business)
    if short_dts > frame_b_pts
      image_list.from_blob(frame.to_ppm)
      break
    end
    
    # grab the frame if current frame dts
    # greater than one we want
    # used this logic since seeking inaccuracies allow the
    # desired seek time to be less than frame_a_pts
    if current_seek_time <= short_dts
      image_list.from_blob(frame.to_ppm)
      current_seek_time = seek_times.pop
    end
  end
end


# dump out the images
image_list.each_with_index do |image, index|
  image.write("thumb_#{index}.png")
end
  
