#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/kirk #needed for cron automation because cron gets limited env variables
#specify ulimit explicitly just in case cron doesn't get the memo
ulimit -n 4096
ulimit -t unlimited
echo starting script > /home/kirk/Documents/3Body/cron_log.txt #suppress output and put into text file, added for debugging from cron
cd /home/kirk/Documents/3Body
oldAnim="/home/kirk/Documents/3Body/3Body_fps30.mp4"
if [ -f $oldAnim ] ; then
    rm $oldAnim #not strictly necessary, but removing prevents tweeting out old animation if there is an error
fi
LOGFILE="/home/kirk/Documents/3Body/jCronErr.log"
./threeBodyProb.jl > $LOGFILE 2>&1 #log any specific errors generated in julia script
echo animation generated, running ffmpeg >> /home/kirk/Documents/3Body/cron_log.txt
cd tmpPlots
</dev/null ffmpeg -framerate 30 -i "%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -fs 15M -vf "scale=720:720,setdar=1/1" "/home/kirk/Documents/3Body/3Body_fps30.mp4"
echo removing png files >> /home/kirk/Documents/3Body/cron_log.txt
rm *.png
cd ../twitterbot
./server.js
echo script ran successfully >> /home/kirk/Documents/3Body/cron_log.txt
