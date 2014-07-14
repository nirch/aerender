require 'sinatra'

$sum = 0

Thread.new do # trivial example work thread
  while true do
     sleep 0.12
     $sum += 1
  end
end

get '/' do
  "Testing background work thread: sum is #{$sum}"
end