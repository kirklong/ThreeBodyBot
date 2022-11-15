#!/usr/bin/env python
import pytumblr,pickle

client = pickle.load(open("client.p","rb"))
with open("/home/kirk/Documents/3Body/initCond.txt") as f:
    initCond=f.read()
    n = len(f.readlines())

title = "Random three-body problem" if n<6 else "Random {}-body problem".format(n-4)

blogName="threebodybot.tumblr.com"
caption=""
body=initCond

client.create_video(blogName,caption=body,data="/home/kirk/Documents/3Body/3Body_fps30_wMusicAAC.mp4")


