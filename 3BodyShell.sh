#!/usr/bin/env bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/kirk #needed for cron automation because cron gets limited env variables
#specify ulimit explicitly just in case cron doesn't get the memo
ulimit -n 4096
ulimit -t unlimited
echo 'starting script' > /home/kirk/Documents/3Body/cron_log.txt #suppress output and put into text file, added for debugging from cron
cd /home/kirk/Documents/3Body
oldAnim="/home/kirk/Documents/3Body/3Body_fps30.mp4"
if [ -f $oldAnim ] ; then
    rm *.mp4 #not strictly necessary, but removing prevents tweeting out old animation if there is an error
    #remove all mp4 videos, not just oldAnim (with adding music others are created)
fi
LOGFILE="/home/kirk/Documents/3Body/jCronErr.log"
./threeBodyProb.jl > $LOGFILE 2>&1 #log any specific errors generated in julia script
echo 'frames generated, running ffmpeg' >> /home/kirk/Documents/3Body/cron_log.txt
cd tmpPlots
</dev/null ffmpeg -framerate 30 -i "%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -fs 15M -vf "scale=720:720,setdar=1/1" "/home/kirk/Documents/3Body/3Body_fps30.mp4"
echo 'animation generated, removing png files' >> /home/kirk/Documents/3Body/cron_log.txt
rm *.png
cd /home/kirk/Documents/3Body
echo 'adding music' >> /home/kirk/Documents/3Body/cron_log.txt
echo ' ' >> /home/kirk/Documents/3Body/initCond.txt #so next thing goes to new line
num=$((1+RANDOM%17)) #get number between 1 and 9
if [ $num -eq 1 ]; then
  echo 'Music: Adagio for Strings -- Barber' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 2 ]; then
  echo 'Music: The Blue Danube Waltz -- Strauss' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 3 ]; then
  echo 'Music: Moonlight Sonata (1st Mvmt) -- Beethoven' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 4 ]; then
  echo 'Music: Clair de Lune -- Debussy' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 5 ]; then
  echo 'Music: Gymnopédie No. 1 -- Satie' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 6 ]; then
  echo 'Music: Symphony No. 5 (1st Mvmt) -- Beethoven' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 7 ]; then
  echo 'Music: First Step (Interstellar) -- Zimmer' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 8 ]; then
  echo 'Music: Time (Inception) -- Zimmer' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 9 ]; then
  echo 'Music: I Need a Ride (The Expanse) -- Shorter' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 10 ]; then
  echo 'Music: Prelude in E Minor -- Chopin' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 11 ]; then
  echo 'Music: Prelude in C# Minor (Posthumous) -- Chopin' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 12 ]; then
  echo 'Music: Battlestar Sonatica (BSG) -- McCreary' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 13 ]; then
  echo 'Music: Rhapsody in Blue (solo piano) -- Gershwin' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 14 ]; then
  echo 'Music: Passacaglia (BSG, solo piano) -- McCreary' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 15 ]; then
  echo 'Music: Prelude in G Minor -- Rachmaninoff' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 16 ]; then
  echo 'Music: Prelude in C# Minor -- Rachmaninoff' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 17 ]; then
  echo 'Music: The Shape of Things To Come (BSG, solo piano) -- McCreary' >> /home/kirk/Documents/3Body/nbody/initCond.txt
fi

musicFile="/home/kirk/Documents/3Body/music/music_choice_${num}.mp3"
videoFile="/home/kirk/Documents/3Body/3Body_fps30.mp4"
combinedFile="3Body_fps30_wMusic.mp4"
combinedAACOut="3Body_fps30_wMusicAAC.mp4"
ffmpeg -i $videoFile -i $musicFile -codec copy -shortest $combinedFile #combine audio w/video
ffmpeg -i $combinedFile -codec:a aac -preset slow $combinedAACOut #change audio to aac lc format for twitter
cd twitterbot
./server.js
echo 'script ran successfully' >> /home/kirk/Documents/3Body/cron_log.txt
