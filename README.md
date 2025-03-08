# Random Three-Body Simulation Generator (***with Twitter/Tumblr/YouTube/Mastodon bot***)

<!-- <img align="left" src="figure8.gif" width="380" height="380"> -->
![Figure 8 solution](figure8.gif)

A cool stable solution to the three-body problem created by the code, based off of [Chenciner and Montgomery (2000)](https://arxiv.org/pdf/math/0011268.pdf). See all the animations on the bot's ~~[Twitter](https://twitter.com/ThreeBodyBot)~~, [Tumblr](https://www.tumblr.com/threebodybot), [YouTube](https://www.youtube.com/@ThreeBodyBot), or [Mastodon](https://mathstodon.xyz/@threebodybot)!

### What people are saying about @ThreeBodyBot:

"I'm Jessie Christiansen and I stan the Random Three Body Problem twitter account." – [Dr. Jessie Christiansen](https://twitter.com/aussiastronomer/status/1263121973082681347)

"Mesmerizing bot" – [Emily Lakdawalla](https://twitter.com/elakdawalla/status/1263075152691990533)

"is this trisolaran propaganda" – [adam from Twitter](https://twitter.com/gains_tweets/status/1263103612168712194)

"shit I should really improve this code now that people other than me might look at it" – [@ThreeBodyBot's inept parent](https://www.kirklong.space)

<br/>

### The three-body simulation generator
This is a fun little pet project I put together in Julia that renders a random gravitational three-body simulation in two dimensions. It's a simple program that uses an explicit implementation of fourth order Runge-Kutta to simulate the system over a specified timescale. In addition to stopping after a specified amount of time, the simulation will quit if there is a collision between bodies or one or more bodies is ejected from the system. It then makes a pretty animation (complete with randomly generated fake background stars!) and saves it locally. This thing is now pretty much finalized, or at least at v1.0. As of January 2021 the bot has also started tracking its stats, outputting the results of each night's simulation into a text file ([`3BodyStats.txt`](3BodyStats.txt)) that's read in and analyzed with the notebook [`3BodyAnalysis.ipynb`](3BodyAnalysis.ipynb), which makes a pretty array of plots showcasing where the bot has been. The longest "solution" the bot has ever found was a system that lasted a little over 14,000 years, and you can find that immortalized [here](https://www.youtube.com/watch?v=BnN_6AUB_bg). The tweet thread in the bot's bio contains a record of all of the longest simulations ands is updated each time it beats its own record if you want to see previous record holders!


### A lazy n-body generator...
There are several scripts in the [`nbody`](nbody) folder worth looking at if you are looking to create even more gravitational chaos. These will start occasionally popping up on the bot's accounts, and there are new instructions below that should get you started if you want to try to make one of these yourself! The camera implementation with these is still a little buggy though...so I've currently disabled them until I get around to fixing that. If you have great ideas on what should be done to improve it please do so and I will happily credit and merge your changes. I think I can apply the improved camera system from the three-body versions here, but I need to actually sit down and spend a day doing it...

### The math / procedural details
The simulations use Newtonian gravity only to simulate the system, i.e. each body's motion is governed simply by:

$$\mathbf{a_i} = \ddot{\mathbf{r_i}} = \sum_{j\neq i} -GM_{j}\frac{\mathbf{r_i - r_j}}{r_{ij}^3}$$

Where the body at index $i$ is the body being moved and $j \neq i$ the bodies that $i$ is attracted towards, with $i$ running from 1 to the total number of bodies (i.e. in the three-body case $i$ runs from 1 to 3). $G$ is Newton's gravitational constant, $M$ is the mass, and $\mathbf{r}$ the position vector (with $r_{ij}$ corresponding to the distance between two bodies $i$ and $j$). This second-order differential equation is split into two coupled first-order differential equations ($\dot{\mathbf{r}} = \mathbf{v}$ and $\dot{\mathbf{v}} = \mathbf{a}$) and integrated with an adaptive time stepping 4th order Runge-Kutta procedure ensuring that the total error of each simulation is <0.001% (measured from change in total energy of the system). The equations are integrated in 2D cartesian space (2D looks cleaner in visualizations and makes collisions more frequent, which is fun), although simple 3D versions of the code are hosted here as well if you're interested. For a more in-depth walk-through / analysis see the materials in the [`NumericsTutorial`](NumericsTutorial) folder, which includes a nice tutorial on how to build your own n-body simulator from scratch!

### The /Tumblr/YouTube/Mastodon bot
For *Twitter*:
This is my first experience with JavaScript and the Twitter API, so it's mostly cobbled together code from the Twit [documentation](https://www.npmjs.com/package/twit), this auto-tweeting image bot [code](https://github.com/fourtonfish/random-image-twitterbot/blob/master/server-attribution.js), and this video tweeting example from [Loren Stewart](https://lorenstewart.me/2017/02/03/twitter-api-uploading-videos-using-node-js/).

**Update:** Twitter finally disabled my free access to the v1.1 API (4 months after they were supposed to), so the bot now uses the Python package [`tweepy`](https://www.tweepy.org/), but I have kept the examples linked above as they were still immensely useful for my learning.

To tweet from a script you need a developer account with Twitter so that you can fill in API keys (see [`configSample.js`](twitterbot/configSample.js)). The script the bot originally used to upload to Twitter is at [`server.js`](twitterbot/server.js), but unfortunately the Twit package only supports (at this writing) the v1.1 API which Twitter recently locked behind a paywall. The bot now tweets using the Python script [`tweepy_bot.py`](twitterbot/tweepy_bot.py) as [`tweepy`](https://www.tweepy.org) supports the v2 API, but I've kept both versions here on GitHub for those who might be curious.

**Second update:** Sadly, the bot is really dead now...on Twitter anyways (thanks Elon...) but it lives on in other places! Read more below:

For *Tumblr*:
I used the great [pytumblr](https://github.com/tumblr/pytumblr) module (and accompanying documentation there) to upload the simulations to a [tumblr blog](https://www.tumblr.com/threebodybot). You need to register your application to get authentication keys to be able to post but the process is pretty easy with Tubmlr! The script that does the uploading is [`bot.py`](tumblrBot/bot.py).

For *YouTube*:
This was the trickiest one... YouTube has a great and easy API to use like Tumblr, but they don't let you publish the videos you upload via their API to the public unless you "verify" your app, which requires a lot of red tape. Part of that verification process is showing how your app works and that it will be used by > 100 people...and on these grounds they denied verifying my app, so I had to get a little crafty. Ended up using this wonderful [Opplast](https://github.com/offish/opplast) repo and instructions therein to accomplish this, but the way this works is significantly less stable over time than if YouTube would just let me use their API to upload, so if you're reading this and you work at YouTube (or know someone who does) and want to help me verify my app please reach out! The script that does the uploading to YouTube is [`opplastUpload.py`](YouTubeBot/opplastUpload.py) and you can find the bot's YouTube channel [here](https://www.youtube.com/channel/UCB6dRXvYWpOqEA3oHUS6xYA).

**Update**: They figured out this work-around and it stopped working and I'm too lazy to find another one...so for now I manually upload only the extended cuts to the bot's YouTube page. 

For *Mastodon*:
Like Tumblr, Mastodon has a nice Python API wrapper ([Mastodon.py](https://github.com/halcy/Mastodon.py)) that I use to upload the videos to the [bot's Mastodon account](https://mathstodon.xyz/@threebodybot). Again you need to register your application to get authentication keys but like Tubmlr it's pretty painless! With Mastodon you also have to make sure the server allows bots, which is why I originally chose to host the bot on [bots.inspace](https://bots.inspace). This server has since shut down but the bot has found a new home on [Mathstodon](https://mathstodon.xyz/home). The script that takes care of uploading the videos to Mastodon is [`MastodonUpload.py`](MastodonBot/MastodonUpload.py).

## Want to generate your own animations?

***Overwhelmed by lots of instructions and want me to just do it for you?*** DM the bot a donation receipt showing you supported an org fighting for civil rights  (ie places like the [Equal Justice Initiative](https://eji.org/), [Human Rights Campaign](https://www.hrc.org/), [ACLU](https://www.aclu.org/), etc.)  and I will do the heavy lifting for you! I will happily make you a classic three-body version, a 3D three-body version, or you can request one of my new fancy new n-body simulations – you can even pick colors and name the stars!  Here's an example of a fun custom thing I recently put together in honor of the new Dune movie: 

![Dune.gif](Dune/Dune.gif)

***Now back to the details...***

If you're on Windows, there's now a 15 minute [tutorial video](https://www.youtube.com/watch?v=bXrXwgC9Ltk&feature=youtu.be) that walks you through the entire process, from installing Julia to making your first animation! If there's interest I will also make one demonstrating the process on Linux, but I'm assuming most people who are running Linux won't need/want a tutorial. Unfortunately I don't have access to a Mac, so can't make one for macOS. Hopefully between the Windows video and the instructions below you can sort it out, sorry! 

Don't want to download anything / tinker with your own computer? One of my students [Navan Chauhan](https://github.com/navanchauhan) recently deployed the bot on Google Colab, and you can play with it here if you like: [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/drive/1w-NeVdZp-AT4gO7A2aOvBaJbHdupy2y0?usp=sharing)

Note that Colab by default doesn't work with Julia, so each time you run the notebook you have to install Julia which takes a few minutes and can sometimes be a little buggy. 

To make the classic three-body animations with this code all you really need to download (in addition to Julia) is the [`threeBodyProb.jl`](threeBodyProb.jl) script. There are comments there that hopefully explain how to use it and change the options so that you can start generating your own interesting systems! If you want to specify initial conditions (instead of having them be randomly generated) this script should be easy to modify to accomplish that goal. There are also a few other versions of the three-body problem script that are a bit less polished, including a full 3D version [`threeBody3D.jl`](threeBody3D.jl) and a three-paneled 3D version ([`threeBody3Panel.jl`](threeBody3Frame.jl).

A simple first thing to do would be to launch a Julia terminal window in the same directory as you've downloaded the script to, make a subdirectory called "tmpPlots", then at the REPL type ```include("threeBodyProb.jl")```. Then after that finishes running typing ```makeAnim()``` in that same terminal window should generate the animation, assuming you have FFmpeg installed. To make another animation you could then type ```main()``` to generate the frames again, then ```makeAnim()``` to compile another animation, and so on and so forth.

If you don't have FFmpeg installed you could try using Julia's built-in animation suite – I used to do it this way, and the "legacy" code is still there at the bottom of the script, but you'll have to do some tinkering to get it to play nice, and you won't be able to do the cool collision cam without some heavy modification. There are comments in the script that hopefully point this out / guide you on what you would need to do if you want to do this. For more advanced control over how the animations are generated and to take advantage of all the coolest features you will need to generate the animation frames using the fancier method (default, see above) with `makeAnim()` – by default it assumes there is an empty subdirectory called "tmpPlots" it can place the png files that you'll either need to create, or alternatively modify the code to remove that bit. The FFmpeg method also generates the frames and renders the animation ***significantly*** faster than the built-in suite does, at least in older versions of Julia (haven't used it in a while). It's on my "someday" to-do list to turn this into an actual binary "app" that you could run without even having Julia installed, but until that happens you have to get a little bit into the weeds, sorry! There is a nice set of instructions at the top of [`threeBodyProb.jl`](threeBodyProb.jl) that should help you get up and running though, and once you have that working if you want to use the other scripts it should be easy to incorporate.  

The [`3BodySetup.ipynb`](3BodySetup.ipynb) notebook is more of the stream of consciousness I had while creating this project and testing different things, but it may be useful if you want to see how things are tweaked (but it's not very well documented sorry).

The shell script ([`3BodyShell.sh`](3BodyShell.sh)) depends almost entirely on filepaths to my machine and requires use of the Twitter/Tumblr/YouTube/Mastodon APIs through their respective upload scripts but is a good template to base your own off of (if you desire), and the FFmpeg command there by itself may be useful. It's also fun if you just want to see the entire pipeline for how the animations get generated and posted start to finish.

**If you want to make n-body simulations**, you need either the [`requests.jl`](nbody/requests.jl) or [`namedBody.jl`](nbody/namedBody.jl) code from the `nbody` folder – use the [`namedBody.jl`](nbody/namedBody.jl) version if you want to give the stars actual names (as opposed to just masses) and the [`requests.jl`](nbody/requests.jl) version for everything else. Yes, reader, I could (and probably should) have combined these into one file but I'm exceptionally lazy and for some reason thought it was easier to make two when I did it late the other night so sorry. Both of these scripts have command line arguments that change interactivity. For example, to generate square frames for a 10 body simulation with random masses, colors, and without fun names one would execute something like `julia requests.jl 10 0 0 0`. Like in the three-body code you will need to alter the filepath to where the frames are saved, and use something like FFmpeg to compile the frames after they are generated.

The code is licensed (as of 9/25/2021) with the [GNU General Public License v3.0](LICENSE), which in TL;DR form essentially means you can do whatever you like with this code *as long as you keep it open-source and freely available*. A couple people have reached out to ask if they can make NFTs with the code, which I've politely declined as I think that goes against the spirit of the project and the GNU License (NFTs are inherently *not* free and open-source by design). 

If you want to see how the bot works under the hood, check out the [`NumericsTutorial`](NumericsTutorial) folder, which contains a ready-to-run notebook that walks through the math/numerics of how the bot works, culminating in a fun n-body simulator at the end! The fun Dune example linked above was created based on this notebook, so if you want to do n-body simulations with sand worms check out [`Dune/Worm.ipynb`](Dune/Worm.ipynb) in the Dune folder.

### Prerequisites

To run the Julia code you will need [Julia](https://julialang.org/downloads/platform.html) installed on your machine and within Julia you will need the Plots, Random, and Printf [packages installed](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html). If you want to run the Jupyter Notebook you will also need to have the [IJulia package](https://github.com/JuliaLang/IJulia.jl).

To tweet the animations from the server.js script you will need a developer account and an application with keys you can populate to the [`configSample.js`](twitterbot/configSample.js) file. [This](https://www.makeuseof.com/tag/photo-tweeting-twitter-bot-raspberry-pi-nodejs/) is a helpful tutorial I loosely followed. You will need [Node.js](https://nodejs.org/en/download/) installed with the package [Twit](https://www.npmjs.com/package/twit) added.

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
* [Node.js](https://nodejs.org/en/) – to post the animations to Twitter from 12/2019 - 6/2023 (with the help of [twit](https://www.npmjs.com/package/twit)).
* [Python](https://www.python.org/) - to post the animations to Twitter from 6/2023 - present (with the help of [tweepy](https://www.tweepy.org/)) as well as posting to Tubmlr (with the help of [pytumblr](https://github.com/tumblr/pytumblr), YouTube (which intermittently works with the help of [opplast](https://github.com/offish/opplast)), and Mastodon (with the help of [Mastodon.py](https://github.com/halcy/Mastodon.py))
* [Bash](https://www.gnu.org/software/bash/) – to pull all scripts together and manage the resulting files.

## Author

 **Kirk Long**


## Acknowledgments

* Incredibly grateful for the Node.js examples used in creating the Twitter bot already mentioned above.

* Also grateful for Dr. Olga Goulko, whose class I took Fa2018 enabled me to develop the skills to put together a project like this – parts of this Julia code were repurposed from my final project in her class, where I generated a Saturn V physics simulation in Python.

* To create this README I followed this excellent [template](https://gist.github.com/PurpleBooth/109311bb0361f32d87a2).

* Thanks to [Hunter Coleman](https://twitter.com/hunto_cole) for noticing a minor error in the initCondGen() function where distances were calculated improperly.

* Thanks to [Tasos Papastylianou](https://stackoverflow.com/users/4183191/tasos-papastylianou) for his help in [debugging](https://stackoverflow.com/questions/59515953/julia-program-stalls-when-run-from-crontab-scheduler-linux?noredirect=1#comment105234026_59515953) a very tricky error when my program was not running correctly initially when scheduled with cron.

* Thanks to my research advisor Dr. Daryl Macomb for not answering my questions right away, giving me the free time over winter break to initially create this bot.

* Thanks to my ASTR 2030 Black Holes student Navan Chauhan for deploying the bot to Colab!

* Musical selections that accompany animations:

  1. [Adagio for Strings – Barber](https://www.youtube.com/watch?v=tVNhFMZP4NM)

  2. [The Blue Danube Waltz – Strauss](https://www.youtube.com/watch?v=cKkDMiGUbUw)

  3. Moonlight Sonata (1st Movement) – Beethoven (recorded by me)

  4. Clair de Lune – Debussy (recorded by me)

  5. Gymnopédie No. 1 – Satie (recorded by me)

  6. [Symphony No. 5 – Beethoven](https://www.youtube.com/watch?v=_4IRMYuE1hI)

  7. First Step (from the Interstellar soundtrack) – Zimmer (piano cover and recording by me)

  8. Time (from the Inception soundtrack) – Zimmer (piano cover and recording by me)

  9. [I Need a Ride (from The Expanse season 3 soundtrack) – Shorter](https://www.youtube.com/watch?v=sbWmzoL4FwM)

  10. Prelude in E Minor – Chopin (recorded by me)

  11. Nocturne in C# Minor (Posthumous) – Chopin (recorded by me)

  12. Battlestar Sonatica (from the Battlestar Galactica season 3 soundtrack) – McCreary (recorded by me)

  13. Rhapsody in Blue (solo piano version) – Gershwin (recorded by me)

  14. Passacaglia (from the Battlestar Galactica season 2 soundtrack) – McCreary (piano cover recorded by me)

  15. Prelude in G Minor – Rachmaninoff (recorded by me)

  16. Prelude in C# Minor – Rachmaninoff (recorded by me)

  17. The Shape of Things to Come (from the Battlestar Galactica season 2 soundtrack) – McCreary (piano cover recorded by me)

  18. Prelude in C Major – Bach (recorded by me)

  19. Liebestraum – Liszt (recorded by me)

  20. Where is My Mind – Pixies (piano cover by Maxence Cyrin, recorded by me)

  21. Lost (from The Expanse season 2 soundtrack) – Shorter (piano cover and recording by me)

  22. What Did You Do (from The Expanse season 2 soundtrack) – Shorter (piano cover and recording by me)

  23. [Waltz of the Flowers – Tchaikovsky](https://www.youtube.com/watch?v=QxHkLdQy5f0)

  24. Memories of Green (from the Bladerunner soundtrack) – Vangelis (piano cover and recording by me, this one has two different sections recorded the bot randomly picks from)
  
  25. Dune (2021) Medley – Zimmer (piano cover and recording by me)

  26. [Aurorae Chaos – Bourquenez](https://johannbourquenez.com/faircamp/johann-bourquenez-aurorae-chaos/) (recording provided by [composer](https://johannbourquenez.com/))

  27. [Ballad with Modulations – Bourquenez](https://johannbourquenez.bandcamp.com/track/ballad-with-modulations) (recording provided by [composer](https://johannbourquenez.com/))

**Disclaimer:** Although I think this project justifiably falls under fair use (purely educational/no money involved/only short snippets used) I have attempted to contact everyone who might have a copyright issue with this anyways in the name of good faith – they have either not replied or granted permission for this limited use. I've also tried to record my own versions of all pieces used (when possible), putting my music minor to good use and hopefully further mitigating any copyright issues. That being said, if you are the copyright owner to any of these tracks (particularly the movie/TV ones) and you do not want them used in the animations I will happily remove them as an option for the bot at your request.
