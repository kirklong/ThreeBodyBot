#!/usr/bin/env python

# Client.send_video helper introduced in 0.0.54
from atproto import Client

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


def send_post(at_client: Client, text: str, media: bytes, alt_text: str) -> bool:
    """Send post with the given text content and video bytes
    """
    print(f"Sending post with text:\n{text}")

    try:
        at_client.send_video(
            text=text,
            video=media,
            video_alt=alt_text,
        )
    except Exception as ex:
        print("Failed to send post. Got error: ", str(ex))
        return False
    return True


def main():

    # Login to BlueSky
    at_client: Client = at_login()

    # Read video file from filesystem
    with open("3Body/3Body_fps30_wMusicAAC.mp4", 'rb') as f:
        video_bytes: bytes = f.read()

    # Read initial conditions from file
    with open("3Body/initCond.txt") as f:
        initCond: str = f.read()

    description = "Initial conditions:\n" + initCond

    attempts = 0
    success = False
    while attempts < 12 and not success:
        attempts += 1
        print(f"Attempt {attempts} posting to BlueSky...")
        success = send_post(
            at_client=at_client,
            text=description,
            media=video_bytes,
            alt_text="astrophysics simulation of the gravitational interaction of three bodies with random initial conditions",
        )
        print("Posted to BlueSky!")
    if not success:
        print("Error posting to BlueSky")


if __name__ == "__main__":
    main()
