#!/usr/bin/env node
var fs = require('fs'),

    path = require('path'),

    Twit = require('twit'),

    config = require(path.join(__dirname, 'config.js'));
var T = new Twit(config);

function upload_video(){
  console.log('Opening video...');
  var video_path = '/home/kirk/Documents/3Body/3Body_fps30.gif'
    //  b64content = fs.readFileSync(video_path, { encoding: 'base64' });

//  console.log('Uploading video...');
    T.postMediaChunked({
      file_path: video_path,
      media_category: 'tweet_gif'
    }, function (err, data, response) {
      if (err){
        console.log('ERROR:');
        console.log(err);
      }
      else{
        console.log('Video uploaded!');
        console.log(data)
      }
    const mediaIdStr = data.media_id_string
//    if (err){
//	console.log('ERROR:');
//	console.log(err);
//   }

//  T.post('media/upload', { media_data: b64content }, function (err, data, response) {
//    if (err){
//      console.log('ERROR:');
//      console.log(err);
//    }
//    else{
//      console.log('Image uploaded!');
//      console.log('Now tweeting it...');
     try {
	   var tweet_text=fs.readFileSync('/home/kirk/Documents/3Body/initCond.txt','utf8')
	   console.log(tweet_text)
	  } catch (err) {
	    console.error(err)
	  }
      T.post('statuses/update', {
	        status: 'initial conditions:\n'+tweet_text+'\n#ThreeBodyProblem #physics #scicomm',
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
// }

upload_video();
