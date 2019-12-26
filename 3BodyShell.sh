#!/bin/sh
cd ~/Documents/3Body
./threeBodyProb.jl
cd twitterbot
./server.js
echo script ran successfully
