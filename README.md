# ytgif

Usage: `ytgif [OPTIONS] <youtube-url> <output_file>`

Download the video named in youtube-url and create a gif of it. Will embed the auto-generated subtitles if they're available. Start and finish times should be in ffmpeg format.

## OPTIONS

```
  -v:             print more verbose output
  -scale n:       scale the video's with to n pixels [default 640]
  -fps n:         set the fps of the output gif [default 20]
  -gifsicle:      post-process the image with `gifsicle -O2`
  -start time:    the time to start the video at
  -finish time:   the time to finish the video at
  -nosubs:        do not include subtitles in the outputeven if they're available
  -sub-lang lang: sub language to choose
```

## TIME

    The start and finish times can be specified in seconds, or mm:ss or hh:mm:ss.ms. ffmpeg is flexible in what it accepts. https://trac.ffmpeg.org/wiki/Seeking

## INSTALLING

    copy ytgif.bash to somewhere on your $PATH and rename it `ytgif`

## EXAMPLES

Download the "I can't believe you've done this" clip, and turn the whole thing into "donethis.gif"

    ytgif "https://www.youtube.com/watch?v=wKbU8B-QVZk" "donethis.gif"

Download the "don't call me shirley" clip from youtube, cut from 1:00 to 1:11.5, lower the fps to 10, and save it as airplane.gif:

    ytgif -start 1:00 -finish 1:11.5 -fps 10 "https://www.youtube.com/watch?v=ixljWVyPby0" "airplane.gif"

Download a bit of a linear algebra lecture, and subtitle it in spanish:

    ytgif -sub-lang es -start 26:54 -finish 27:02 "https://www.youtube.com/watch?v=QVKj3LADCnA" "strang.gif"

NOTES

- Be careful to quote the youtube URL, if it contain the & character it will not work unless quoted
