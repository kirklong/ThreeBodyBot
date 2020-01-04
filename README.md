# Random Three Body Simulation Generator (***with Twitter bot***)

See all animations on the bot's [Twitter](https://twitter.com/ThreeBodyBot)!

### The three body simulation generator
This is a fun little pet project I put together in Julia that renders a random gravitational three body simulation in two dimensions. It's a simple program that uses an explicit implementation of fourth order Runge-Kutta with a fixed step size to simulate the system over a specified timescale. In addition to stopping after a specified amount of time, the simulation will quit if there is a collision between bodies or one or more bodies is ejected from the system. It then makes a pretty animation (complete with randomly generated fake background stars!) and saves it locally.

### The Twitter bot
This is my first experience with JavaScript and the Twitter API, so it's mostly cobbled together code from the Twit [documentation](https://www.npmjs.com/package/twit), this auto-tweeting image bot [code](https://github.com/fourtonfish/random-image-twitterbot/blob/master/server-attribution.js), and this video tweeting example from [Loren Stewart](https://lorenstewart.me/2017/02/03/twitter-api-uploading-videos-using-node-js/).

It's a really basic program but it works (mostly anyways).

To tweet from a script you need a developer account with Twitter so that you can fill in API keys (see configSample.js).

## Want to generate your own animations?

To make the animations with this code all you really need to download is the threeBodyProb.jl script. There are comments there that hopefully explain how to use it and change the options so that you can start generating your own interesting systems! If you want to specify initial conditions (instead of having them be randomly generated) this script should be easy to modify to accomplish that goal.

You should be able to generate an animation right away without changing any settings simply by uncommenting the code past line 271 and commenting out the code segment between lines 235 and 259. If run this way an animation should be generated in the folder where the script was run from. For more advanced control over how the animations are generated you will need to use the method outlined between lines 235 and 259, and you will need to specify some file paths. That method also generates animations ***significantly*** faster. If there is enough interest (or enough confusion) I will try to make a more generalized version of the script that doesn't depend on explicit file paths.

The 3BodySetup.ipynb notebook is more of the stream of consciousness I had while creating this project and testing different things, but it may be useful if you want to see how things are tweaked (but it's not very well documented sorry).

The shell script is (3BodyShell.sh) depends almost entirely on filepaths to my machine and requires use of the Twitter API through ther server.js script but is a good template to base your own off of (if you desire), and the ffmpeg command there by itself may be useful.

### Prerequisites

To run the Julia code you will need [Julia](https://julialang.org/downloads/platform.html) installed on your machine and within Julia you will need the Plots, Random, and Printf [packages installed](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html). If you want to run the Jupyter Notebook you will also need to have the [IJulia package](https://github.com/JuliaLang/IJulia.jl).

To tweet the animations from the server.js script you will need a developer account and an application with keys you can populate to the configSample.js file. [This](https://www.makeuseof.com/tag/photo-tweeting-twitter-bot-raspberry-pi-nodejs/) is a helpful tutorial I loosely followed. You will need [Node.js](https://nodejs.org/en/download/) installed with the package [Twit](https://www.npmjs.com/package/twit) added.

To create the animation (either in Julia or manually) with this script you need to have [FFmpeg installed](https://ffmpeg.org/download.html).

### Errors

If the animation does not render correctly, the most likely culprit is you do not have FFmpeg installed correctly (see above). If you are running on Windows/MacOS there may be minor things that might have to be changed for your system, especially if you are trying to use the more advanced options.

On my machine initially the animations failed to build if they had more than 1024 frames due to a restriction on the number of open files. On Linux you can fix this by typing the following into a terminal:


```
ulimit -n 4096
```

The default hard limit is usually 4096, and that should be ample for most animations. Note that this will only affect the current shell and will not change the limit permanently. To do that you will need to [alter your /etc/security/limits.conf file](https://sysadminxpert.com/change-ulimit-values-permanently-for-a-user-or-all-user-in-linux/).

If this doesn't work, check what your hard limit is specified as:

```
ulimit -Hn
```

You can modify the hard limit in the /etc/security/limits.conf file mentioned above if needed (you will probably need to if you are making animations longer than 4096 frames/~2.5 min at 30 fps).


## Built With

* [Julia](https://julialang.org/) – to simulate the system and create the animation frames.
* [FFmpeg](https://ffmpeg.org/) – to render the animations and integrate audio files.
* [Node.js](https://nodejs.org/en/) – to post the animations to Twitter (with the help of [twit](https://www.npmjs.com/package/twit)).
* [Bash](https://www.gnu.org/software/bash/) – to pull all scripts together and manage the resulting files.


## Author

 **Kirk Long**


## Acknowledgments

* Incredibly grateful for the Node.js examples used in creating the Twitter bot already mentioned above.

* Also grateful for Dr. Olga Goulko, whose class I took Fa2018 enabled me to develop the skills to put together a project like this – parts of this Julia code were repurposed from my final project in her class, where I generated a Saturn V physics simulation in Python.

* To create this README I followed this excellent [template](https://gist.github.com/PurpleBooth/109311bb0361f32d87a2).

* Thanks to Hunter Coleman for noticing a minor error in the initCondGen() function where distances were calculated improperly.

* Thanks to [Tasos Papastylianou](https://stackoverflow.com/users/4183191/tasos-papastylianou) for his help in [debugging](https://stackoverflow.com/questions/59515953/julia-program-stalls-when-run-from-crontab-scheduler-linux?noredirect=1#comment105234026_59515953) a very tricky error when my program was not running correctly initially when scheduled with cron.

* Musical selections that accompany animations:

  1. [Adagio for Strings -- Barber](https://www.youtube.com/watch?v=tVNhFMZP4NM)

  2. [The Blue Danube Waltz -- Strauss](https://www.youtube.com/watch?v=cKkDMiGUbUw)

  3. [Moonlight Sonata (1st movement) -- Beethoven](https://www.youtube.com/watch?v=4Tr0otuiQuU)

  4. [Clair de Lune -- Debussy](https://www.youtube.com/watch?v=CvFH_6DNRCY)

  5. [Gymnopédie No. 1 -- Satie](https://www.youtube.com/watch?v=S-Xm7s9eGxU)

  6. [Symphony No. 5 -- Beethoven](https://www.youtube.com/watch?v=_4IRMYuE1hI)

  7. [First Step (from the Interstellar soundtrack) -- Zimmer](https://www.youtube.com/watch?v=IDsCtDRV2uA)

  8. [Time (from the Inception soundtrack) -- Zimmer](https://www.youtube.com/watch?v=RxabLA7UQ9k)

  9. [I Need a Ride (from The Expanse season 3 soundtrack) -- Shorter](https://www.youtube.com/watch?v=sbWmzoL4FwM)

**Disclaimer:** Although I think this project justifiably falls under fair use (purely educational/no money involved) I have attempted to contact everyone who might have a copyright issue with this anyways in the name of good faith--they have either not replied or granted permission for this limited use. That being said, if you are the copyright owner to any of these tracks (particularly the movie/TV ones) and you do not want them used in the animations I will happily remove them as an option for the bot at your request.
