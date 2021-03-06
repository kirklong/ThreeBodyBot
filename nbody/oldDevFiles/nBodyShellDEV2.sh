#!/bin/bash

#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/kirk #needed for cron automation because cron gets limited env variables
#specify ulimit explicitly just in case cron doesn't get the memo
ulimit -n 4096
ulimit -t unlimited
for i in {1..10}
do
  echo 'cleaning up old files'
  rm -f tmpPlots2/*.png
  echo 'starting script'
  echo "running iteration $i of 10"
  ./nBodyProbDEV2.jl $1 $2 $3 $4
  echo 'running ffmpeg'
  ffmpeg -framerate 30 -i "tmpPlots2/frame_%06d.png" -c:v libx265 -preset slow -coder 1 -movflags +faststart -g 15 -crf 20 -pix_fmt yuv420p -y -bf 2 -vf "scale=1920:1080" "/home/kirk/Documents/3Body/nbody/NBodyDEV2_fps30_$i.mp4"
done
