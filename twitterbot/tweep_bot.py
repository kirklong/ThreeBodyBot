#!/usr/bin/env python
import tweepy

#read in keys and tokens
with open("consumer_key") as f:
    consumer_key = f.read().strip()
with open("consumer_secret") as f:
    consumer_secret = f.read().strip()
with open("access_token") as f:
    access_token = f.read().strip()
with open("access_token_secret") as f:
    access_token_secret = f.read().strip()
with open("BearerToken") as f:
    bearer_token = f.read().strip()

def upload_media(filename): #v1.1 API for uploading video
    print("uploading video...")
    tweepy_auth = tweepy.OAuth1UserHandler(consumer_key, consumer_secret, access_token, access_token_secret)
    api = tweepy.API(tweepy_auth)
    media = api.media_upload(filename,chunked=True,wait_for_async_finalize=True,media_category="tweet_video")
    #payload = {"media": {"media_ids": [media.media_id_string]}}
    success = media.processing_info['state'] == 'succeeded'
    if success:
        return media
    else:
        print("failed to upload video -- quitting")
        print("media info:")
        print(media)
        return None

def post(text,media_id):
    client = tweepy.Client(consumer_key=consumer_key,
                    consumer_secret=consumer_secret,
                    access_token=access_token,
                    access_token_secret=access_token_secret) #OAuth1 authentication but post to v2 API
    response = client.create_tweet(text=text, media_ids=[media_id])
    if len(response.errors) > 0:
        print("error posting tweet -- errors:")
        print(response.errors)
    else:
        print("successfully posted animation")
    return response

def main():
    filename = "../3Body_fps30_wMusicAAC.mp4"
    media = upload_media(filename)
    if media is not None:
        with open("../initCond.txt") as f:
            initCond = f.read()
        body = "Initial conditions:\n" + initCond
        response = post(body,media.media_id_string)
        print(response)

main()
