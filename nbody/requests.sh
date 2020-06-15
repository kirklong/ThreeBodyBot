#!/usr/bin/env bash

#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/kirk #needed for cron automation because cron gets limited env variables
#specify ulimit explicitly just in case cron doesn't get the memo
ulimit -n 4096
ulimit -t unlimited
echo 'starting script' > /home/kirk/Documents/3Body/nbody/cron_log.txt #suppress output and put into text file, added for debugging from cron
cd /home/kirk/Documents/3Body/nbody
oldAnim="/home/kirk/Documents/3Body/nbody/request_fps30.mp4"
if [ -f $oldAnim ] ; then
    rm request*.mp4 #not strictly necessary, but removing prevents tweeting out old animation if there is an error
    ##remove all mp4 videos, not just oldAnim (with adding music others are created)
fi
##n? pickColors? pickMasses? landscape?
##preset for 7 with nice colors, random everything else
./requests.jl 7 2 0 0 2>"juliaErr.log"
##preset for random everything
num=$((1+RANDOM%17)) #get number between 1 and 17
##./request.jl $num 0 0 0 2>"juliaErr.log"
##preset for more customization -- right now explicit v0 and x0 must be hard-coded in initCondGen
##./request.jl n 1 1 0 2>"juliaErr.log"
echo 'frames generated, running ffmpeg' >> /home/kirk/Documents/3Body/nbody/cron_log.txt
cd tmpPlots2
ffmpeg -framerate 30 -i "frame_%06d.png" -c:v libx265 -preset slow -coder 1 -movflags +faststart -g 15 -crf 20 -pix_fmt yuv420p -y -bf 2 -vf "scale=1024:1024" "/home/kirk/Documents/3Body/nbody/request_fps30.mp4"
echo 'animation generated, removing png files' >> /home/kirk/Documents/3Body/nbody/cron_log.txt
rm *.png
cd /home/kirk/Documents/3Body/nbody
echo 'adding music' >> /home/kirk/Documents/3Body/nbody/cron_log.txt
echo ' ' >> /home/kirk/Documents/3Body/nbody/initCond.txt #so next thing goes to new line
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
  echo 'Music: Prelude in C Sharp Minor (Posthumous) -- Chopin' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 12 ]; then
  echo 'Music: Battlestar Sonatica (BSG) -- McCreary' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 13 ]; then
  echo 'Music: Rhapsody in Blue (solo piano) -- Gershwin' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 14 ]; then
  echo 'Music: Passacaglia (BSG, solo piano) -- McCreary' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 15 ]; then
  echo 'Music: Prelude in G Minor -- Rachmaninoff' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 16 ]; then
  echo 'Music: Prelude in C Sharp Minor -- Rachmaninoff' >> /home/kirk/Documents/3Body/nbody/initCond.txt
elif [ $num -eq 17 ]; then
  echo 'Music: The Shape of Things To Come (BSG, solo piano) -- McCreary' >> /home/kirk/Documents/3Body/nbody/initCond.txt
fi
#1=adagio 4 strings
#2=blue danube
#3=moonlight
#4=clair de lune
#5=gymnopedie 1
#6=beethoven 5
#7=first step/Interstellar
#8=time/Inception
#9=I need a ride/Expanse
musicFile="/home/kirk/Documents/3Body/music/music_choice_${num}.m4a"
videoFile="/home/kirk/Documents/3Body/nbody/request_fps30.mp4"
combinedFile="request_fps30_wMusic.mp4"
combinedAACOut="request_fps30_wMusicAAC.mp4"
ffmpeg -i $videoFile -i $musicFile -codec copy -shortest $combinedFile #combine audio w/video
ffmpeg -i $combinedFile -codec:a aac -preset slow -aspect 1:1 $combinedAACOut #change audio to aac lc format for twitter
#cd twitterbot
#./server.js
#echo 'script ran successfully' >> /home/kirk/Documents/3Body/cron_log.txt
