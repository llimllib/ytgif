# ytgif

Usage: `ytgif [OPTIONS] <youtube-url> <output_file>`

Download the video named in youtube-url and create a gif of it. Will embed the auto-generated subtitles if they're available. You can use the start and finish times to trim it to the duration you'd like.

![](https://github.com/llimllib/ytgif/blob/main/wow.gif?raw=true)

That gif was generated with:

```shell
ytgif -start 74.8 -finish 75.8 -nosubs -gifsicle \
    "https://www.youtube.com/watch?v=KlLMlJ2tDkg&t=50s" wow.gif
```

## OPTIONS

```
-v:             print more verbose output
-scale n:       scale the video's with to n pixels [default 640]
-fps n:         set the fps of the output gif [default 20]
-gifsicle:      post-process the image with `gifsicle -O2`
-start time:    the time to start the video at
-finish time:   the time to finish the video at
-nosubs:        do not include subtitles in the output even if they're available
-sub-lang lang: sub language to choose
-autosubs:      prefer youtube's auto-generated subtitles
-caption text:  use a caption for the entire gif instead of subtitles
-fontsize:      the font size for the caption. Defaults to 30 if caption set,
                otherwise to whatever ffmpeg defaults it to
```

## PREREQUISITES

This script is written for modern bash, and won't work on the ancient bash that OS X ships by default. To install a newer bash, use `brew install bash`. (I tried to work around the old bash, but it's so painful that it makes the script even worse. Sorry)

This script requires [`ffmpeg`](https://ffmpeg.org/) and [`yt-dlp`](https://github.com/yt-dlp/yt-dlp).

[`gifsicle`](https://www.lcdf.org/gifsicle/) is an optional dependency.

This script has only been tested on a mac, where `brew install bash ffmpeg yt-dlp gifsicle` should work to get your dependencies in order. Please report bugs if it fails on other platforms.

## TIME

The start and finish times can be specified in seconds, or mm:ss or hh:mm:ss.ms. ffmpeg is flexible in what it accepts. https://trac.ffmpeg.org/wiki/Seeking

## INSTALLING

After installing the prerequisites, copy `ytgif.bash` to somewhere on your `$PATH` and rename it `ytgif`

## EXAMPLES

Download the "I can't believe you've done this" clip, and turn the whole thing into "donethis.gif"

    ytgif "https://www.youtube.com/watch?v=wKbU8B-QVZk" donethis.gif

Download the "don't call me shirley" clip from youtube, cut from 1:02 to 1:10.9, lower the fps to 10, and save it as airplane.gif:

    ytgif -start 1:02 -finish 1:10.9 -fps 10 \
      "https://www.youtube.com/watch?v=ixljWVyPby0" airplane.gif

Download a bit of a linear algebra lecture, and subtitle it in spanish:

    ytgif -sub-lang es -start 26:54 -finish 27:02 \
      "https://www.youtube.com/watch?v=QVKj3LADCnA" strang.gif

Create a tiny rickroll gif, optimize it, and don't include subtitles:

    ytgif -gifsicle -scale 30 -start 0.5 -finish 3 -nosubs \
     "https://www.youtube.com/watch?v=dQw4w9WgXcQ" rickroll.gif

Create a gif of Gob Bluth, and manually set the caption to "I've made a huge
mistake":

    ytgif -v -start 13 -finish 17 -gifsicle -fps 10 \
     -fontsize 40 -caption "I've made a huge mistake" \
     "https://www.youtube.com/watch?v=GwQW3KW3DCc" mistake.gif

## NOTES

- Be careful to quote the youtube URL, if it contains the & character it will not work unless quoted
- ytgif caches downloaded videos in `/tmp/ytgif_cache`, so you can quickly try edits to the gif without re-downloading videos. These can be quite large, so you may want to clear that folder when you're done making a gif
- youtube's auto subtitles are far from perfect, but often better than nothing
