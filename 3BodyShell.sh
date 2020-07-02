#!/usr/bin/env bash

## first path is for old computer, second for new
#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/kirk #needed for cron automation because cron gets limited env variables
PATH=/home/kirk/Documents/research/MESA/mesasdk/bin:/home/kirk/anaconda3/bin:/home/kirk/anaconda3/condabin:/home/kirk/perl5/perlbrew/bin:/home/kirk/perl5/perlbrew/perls/perl-5.24.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
#PATH=/home/kirk/Documents/research/MESA/mesasdk/bin:/home/kirk/anaconda3/bin:/home/kirk/anaconda3/bin:/home/kirk/anaconda3/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
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
nBody=$((1+RANDOM%7)) #1 and 7 chance of doing nBody simulation
if [ $nBody -eq 1 ]; then
  echo 'n-body simulation!' >> /home/kirk/Documents/3Body/cron_log.txt
  nBodies=$((4+RANDOM%16)) #20 is a lot, and I think close to the limit of what fits in tweet
  cd nbody
  ./requests.jl $nBodies 0 0 0  > $LOGFILE 2>&1
  mv initCond.txt ../
  cd ..
  echo "*** Special ${nBodies}-Body Problem ***"$'\n'"$(cat initCond.txt)" > initCond.txt
else
  ./threeBodyProb.jl > $LOGFILE 2>&1 #log any specific errors generated in julia script
fi
echo 'frames generated, running ffmpeg' >> /home/kirk/Documents/3Body/cron_log.txt
if [ $nBody -eq 1 ]; then
  cd nbody/tmpPlots2
else
  cd tmpPlots
fi
if [ $nBody -eq 1 ]; then
  </dev/null ffmpeg -framerate 30 -i "frame_%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -fs 15M -vf "scale=720:720,setdar=1/1" "/home/kirk/Documents/3Body/3Body_fps30.mp4"
else
  </dev/null ffmpeg -framerate 30 -i "frame_%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -fs 15M -vf "scale=720:720,setdar=1/1" "/home/kirk/Documents/3Body/3Body_fps30.mp4"
fi
echo 'animation generated, removing png files' >> /home/kirk/Documents/3Body/cron_log.txt
rm *.png
cd /home/kirk/Documents/3Body
echo 'adding music' >> /home/kirk/Documents/3Body/cron_log.txt
echo ' ' >> /home/kirk/Documents/3Body/initCond.txt #so next thing goes to new line
num=$((1+RANDOM%23)) #get number between 1 and 23
if [ $num -eq 1 ]; then
  echo 'Music: Adagio for Strings – Barber' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 2 ]; then
  echo 'Music: The Blue Danube Waltz – Strauss' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 3 ]; then
  echo 'Music: Moonlight Sonata (1st Mvmt) – Beethoven' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 4 ]; then
  echo 'Music: Clair de Lune – Debussy' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 5 ]; then
  echo 'Music: Gymnopédie No. 1 – Satie' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 6 ]; then
  echo 'Music: Symphony No. 5 (1st Mvmt) – Beethoven' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 7 ]; then
  echo 'Music: First Step (Interstellar) – Zimmer' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 8 ]; then
  echo 'Music: Time (Inception) – Zimmer' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 9 ]; then
  echo 'Music: I Need a Ride (The Expanse) – Shorter' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 10 ]; then
  echo 'Music: Prelude in E Minor – Chopin' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 11 ]; then
  echo 'Music: Prelude in C-Sharp Minor (Posthumous) – Chopin' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 12 ]; then
  echo 'Music: Battlestar Sonatica (BSG) – McCreary' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 13 ]; then
  echo 'Music: Rhapsody in Blue – Gershwin' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 14 ]; then
  echo 'Music: Passacaglia (BSG) – McCreary' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 15 ]; then
  echo 'Music: Prelude in G Minor – Rachmaninoff' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 16 ]; then
  echo 'Music: Prelude in C-Sharp Minor – Rachmaninoff' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 17 ]; then
  echo 'Music: The Shape of Things To Come (BSG) – McCreary' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 18 ]; then
  echo 'Music: Prelude in C Major – Bach' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 19 ]; then
  echo 'Music: Liebestraum – Liszt' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 20 ]; then
  echo 'Music: Where is My Mind? – Pixies/Cyrin' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 21 ]; then
  echo 'Music: Lost (The Expanse) – Shorter' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 22 ]; then
  echo 'Music: What Did You Do (The Expanse) – Shorter' >> /home/kirk/Documents/3Body/initCond.txt
elif [ $num -eq 23 ]; then
  echo 'Music: Waltz of the Flowers – Tchaikovsky' >> /home/kirk/Documents/3Body/initCond.txt
fi

musicFile="/home/kirk/Documents/3Body/music/music_choice_${num}.m4a"
videoFile="/home/kirk/Documents/3Body/3Body_fps30.mp4"
combinedFile="3Body_fps30_wMusic.mp4"
combinedAACOut="3Body_fps30_wMusicAAC.mp4"
ffmpeg -i $videoFile -i $musicFile -codec copy -shortest $combinedFile #combine audio w/video
ffmpeg -i $combinedFile -codec:a aac -preset slow $combinedAACOut #change audio to aac lc format for twitter
cd twitterbot
./server.js
echo 'script ran successfully' >> /home/kirk/Documents/3Body/cron_log.txt
