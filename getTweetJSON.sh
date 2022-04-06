#! /usr/bin/bash

curl -X GET -H "Authorization: Bearer $(cat BearerToken)" "https://api.twitter.com/2/tweets/$1" > TweetJSON.txt
