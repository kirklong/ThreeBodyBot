#!/usr/bin/env python

from opplast import Upload
from datetime import datetime

with open("/home/kirk/Documents/3Body/initCond.txt") as f:
    initCond = f.read()

date = datetime.today()
title = "Random three-body problem: {0}/{1}/{2}".format(date.month,date.day,date.year)

upload = Upload("/home/kirk/Documents/3Body/YouTubeBot/opplast","/opt/geckodriver")
was_uploaded, video_id = upload.upload(
        "/home/kirk/Documents/3Body/3Body_fps30_wMusicAAC.mp4",
        title=title,
        description=initCond,
        tags=["astrophysics","chaos","codeart"],
        only_upload=False
        )

print("uploaded!") if was_uploaded else print("upload failed")
upload.close()
