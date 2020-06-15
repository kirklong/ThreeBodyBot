#!/usr/bin/env node

var fs = require('fs'),

    path = require('path'),

    Twit = require('twit'),

    config = require(path.join(__dirname, 'config.js'));

var T = new Twit(config);

function upload_video(){
  console.log('Opening video...');
  var video_path = '/home/kirk/Documents/3Body/3Body_fps30_wMusicAAC.mp4'
    T.postMediaChunked({
      file_path: video_path,
      media_type: 'video/mp4',
      media_category: 'tweet_video',
    }, function (err, data, response) {
      if (err){
        console.log('ERROR:');
        console.log(err);
      }
      else{
        console.log('Video uploading...');
        console.log(data)
      }
    const mediaIdStr = data.media_id_string;
    const processState = data.processing_info;
    startTime=Date.now()
    lastTime=Date.now()
      do {
        currentTime=Date.now()
        if ((currentTime-lastTime)/1000==1){
        console.log('...waiting: '+(15-(currentTime-startTime)/1000)+'s remaining');
        lastTime=Date.now()
      }
      }
      while ((Date.now() - startTime) < 30*1000) // need to wait for twitter to process, too lazy to actually query them to check
     try {
	   var tweet_text=fs.readFileSync('/home/kirk/Documents/3Body/initCond.txt','utf8') // get status text from file generated in Julia program
	   console.log(tweet_text)
	  } catch (err) {
	    console.error(err)
	  }
      T.post('statuses/update', {
	        status: 'Initial conditions:\n'+tweet_text // add to status text, attach to media, and tweet
          media_ids: [mediaIdStr]
        },
        function(err, data, response) {
          if (err){
            console.log('ERROR:');
            console.log(err);
          }
          else{
            console.log('Posted video!');
          }
        }
      )
    }
  )
  };

upload_video();

// potential way to query twitter for status if at some point I'm ever not a lazy bitch

// const oAuthCredentials = {
//   consumer_key: 'XXXXXX',
//   consumer_secret: 'XXXXXX',
//   token: 'XXXXX',
//   token_secret: 'XXXXX'
// }

// function (oAuthCredentials, mediaId) {
//   const options = {
//     url: 'https://upload.twitter.com/1.1/media/upload.json',
//     oauth: oAuthCredentials,
//     qs: {
//       command: 'STATUS',
//       'media_id': mediaId
//     }
//   }  try {
//     const resultArray = yield requestGet(options)
//     const body = JSON.parse(resultArray[1])    if (body['processing_info']) {
//       // if processing info is present return it
//       const processingInfo = body['processing_info']
//       return processingInfo
//     } else if (body.errors) {
//       // if body contains errors build message & throw error
//       const message = _.get(body, 'errors.0.message')
//       const code = _.get(body, 'errors.0.code')
//       throw new Error(`${code} ${message}`)
//     } else {
//       // else return custom processing info
//       const processingInfo = {
//         state: 'unknown',
//         console.log(state)
//       }
//       return processingInfo
//     }
//     catch (err) {
//     throw err
//   }
// }

//Another potential way using different library here: https://stackoverflow.com/questions/32231642/uploading-videos-to-twitter-using-api
