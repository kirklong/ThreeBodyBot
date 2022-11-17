#!/usr/bin/env python
from mastodon import Mastodon
import time

m = Mastodon(access_token="usercred.secret")
media = m.media_post("/home/kirk/Documents/3Body/3Body_fps30_wMusicAAC.mp4",description="astrophysics simulation of the gravitational interaction of three bodies with random initial conditions")

with open("/home/kirk/Documents/3Body/initCond.txt") as f:
    initCond = f.read()

description = "Initial conditions:\n" + initCond

media = m.media_update(media['id'])
attempts = 0
while media['url'] == None and attempts < 12:
    time.sleep(5)
    media = m.media_update(media['id'])
    attempts += 1

if attempts < 12: 
    m.status_post(description,media_ids=[media['id']],visibility='public')
    print("posted to Mastodon!")
else:
    print("error posting to Mastodon")

