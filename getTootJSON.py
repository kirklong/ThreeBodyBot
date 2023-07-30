#!/usr/bin/env python
from mastodon import Mastodon
import json, sys
from bs4 import BeautifulSoup

id = sys.argv[1]
m = Mastodon(access_token="MastodonBot/usercred.secret")
status = m.status(id)
soup = BeautifulSoup(status.content,features="lxml")
d = dict(data=dict(id=id,text=soup.get_text('\n')))
with open("TweetJSON.txt","w") as f:
    json.dump(d,f)
