#!/usr/bin/env python

# Spec'ed with atproto==0.0.29. May need to be revised when lexicons change.
from atproto import Client, models

# Read file filesystem instead of env vars to follow existing pattern
with open("BOT_HANDLE") as f:
    BOT_HANDLE = f.read().strip()
with open("BOT_APP_PASSWORD") as f:
    BOT_APP_PASSWORD = f.read().strip()


def at_login() -> Client:
    """Login with the atproto client
    """
    at_client = Client()
    profile = at_client.login(BOT_HANDLE, BOT_APP_PASSWORD)
    print("Logged in as: ", profile.display_name)
    return at_client


def upload_blob(at_client: Client, filename: str, alt_text: str) -> models.AppBskyEmbedImages.Image:
    """Upload a media blob to attach to a post"""

    with open(filename, "rb") as f:
        media_data = f.read()

    upload = at_client.com.atproto.repo.upload_blob(media_data)
    images = [models.AppBskyEmbedImages.Image(alt=alt_text, image=upload.blob)]
    embed = models.AppBskyEmbedImages.Main(images=images)

    return embed


def send_post(at_client: Client, text: str, media: models.AppBskyEmbedImages.Image):
    """Send post with the given text content and media embed
    """
    print(f"Sending post with text:\n{text}")

    try:
        # Manually create post record to include rich text facets
        at_client.com.atproto.repo.create_record(
            models.ComAtprotoRepoCreateRecord.Data(
                repo=at_client.me.did,
                collection=models.ids.AppBskyFeedPost,
                record=models.AppBskyFeedPost.Main(
                    createdAt=at_client.get_current_time_iso(), text=text, embed=media
                )
            )
        )
    except Exception as ex:
        print("Failed to send post. Got error: ", str(ex))
        return False
    return True


def main():
    # Right now this is just a template that works for images since video/gifs are not yet supported on BlueSky.
    # TODO: modify to use correct types once videos are supported (i.e. models.AppBskyEmbedImages)

    # Login to BlueSky
    at_client = at_login()

    media_embed = upload_blob(
        at_client=at_client,
        filename="3Body/3Body_fps30_wMusicAAC.mp4",
        alt_text="astrophysics simulation of the gravitational interaction of three bodies with random initial conditions"
    )

    with open("3Body/initCond.txt") as f:
        initCond = f.read()

    description = "Initial conditions:\n" + initCond

    attempts = 0
    success = False
    if attempts < 12 and not success:
        success = send_post(at_client=at_client, text=description, media=media_embed)
        print("Posted to BlueSky!")
    else:
        print("Error posting to BlueSky")


if __name__ == "__main__":
    main()
