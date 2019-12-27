#!/bin/sh
#ulimit -S 4096 #for longer animations there are more frames than base limit of 1024 open files
ulimit -n 4096
#ulimit -H -c unlimited #changed to get access to core dumps for file size exceeded
#ulimit -S -c unlimited
cd ~/Documents/3Body
oldAnim="/home/kirk/Documents/3Body/3Body_fps30.mp4"
if [ -f $oldAnim ] ; then
    rm $oldAnim #not strictly necessary, but removing prevents tweeting out old animation if there is an error
fi
./threeBodyProb.jl
echo animation generated, running ffmpeg
cd tmpPlots
</dev/null ffmpeg -framerate 30 -i "%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -fs 15M -vf "scale=720:720,setdar=1/1" "/home/kirk/Documents/3Body/3Body_fps30.mp4"
echo removing png files
rm *.png
cd ../twitterbot
./server.js
echo script ran successfully
