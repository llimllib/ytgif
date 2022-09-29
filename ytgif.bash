#!/usr/bin/env bash
set -euo pipefail

# Mac by default ships a version 3 bash that doesn't work with this script. I
# don't know if it works with version 4, and locally I can be sure it works
# with version 5. I'm going to have it quit with an error if the user has less
# than version 4, because that's all I'm sure does not work. Please report
# further version issues https://github.com/llimllib/ytgif
if [ ! "${BASH_VERSINFO:-0}" -ge 4 ]; then
    printf "\033[31mYour version of bash (%s) is too old, please upgrade it to run this script\033[0m\n" "${BASH_VERSINFO[0]}"
    exit
fi

function usage() {
        cat <<"EOF"
Usage: ytgif [OPTIONS] <youtube-url> <output_file>

Download the video named in youtube-url and create a gif of it. Will embed the auto-generated subtitles if they're available. You can use the start and finish times to trim it to the duration you'd like.

OPTIONS

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
  -fontsize:      the font size for the caption. Defaults to 30 if caption set, otherwise to whatever ffmpeg defaults it to

TIME

  The start and finish times can be specified in seconds, or mm:ss or hh:mm:ss.ms. ffmpeg is flexible in what it accepts. https://trac.ffmpeg.org/wiki/Seeking

INSTALLING

  copy ytgif.bash to somewhere on your $PATH and rename it `ytgif`

EXAMPLES

Download the "I can't believe you've done this" clip, and turn the whole thing into "donethis.gif"

  ytgif "https://www.youtube.com/watch?v=wKbU8B-QVZk" donethis.gif

Download the "don't call me shirley" clip from youtube, cut from 1:02 to 1:10.9 lower the fps to 10, and save it as airplane.gif:

  ytgif -start 1:02 -finish 1:10.9 -fps 10 \
    "https://www.youtube.com/watch?v=ixljWVyPby0" airplane.gif

Download a bit of a linear algebra lecture, and subtitle it in spanish:

  ytgif -sub-lang es -start 26:54 -finish 27:02 \
    "https://www.youtube.com/watch?v=QVKj3LADCnA" strang.gif

Create a tiny rickroll gif, optimize it, and don't include subtitles:

  ytgif -gifsicle -scale 30 -start 0.5 -finish 3 -nosubs \
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ" rickroll.gif

Create a gif of owen wilson saying "wow":

  ytgif -start 74.8 -finish 75.8 -nosubs -gifsicle \
    "https://www.youtube.com/watch?v=KlLMlJ2tDkg&t=50s" wow.gif

Create a gif of Gob Bluth, and manually set the caption to "I've made a huge
mistake":

  ytgif -v -start 13 -finish 17 -gifsicle -fps 10 \
    -fontsize 40 -caption "I've made a huge mistake" \
    "https://www.youtube.com/watch?v=GwQW3KW3DCc" mistake.gif

NOTES

- Be careful to quote the youtube URL, if it contain the & character it will not work unless quoted
- ytgif caches downloaded videos in `/tmp/ytgif_cache`, so you can quickly try edits to the gif without re-downloading videos. These can be quite large, so you may want to clear that folder when you're done making a gif
- youtube's auto subtitles are far from perfect, but often better than nothing
EOF
        exit 1
}

verbose=
gifsicle=
scale=640
fps=20
start_=0
finish=()
nosubs=
sublang=
subflags=(--write-subs --write-auto-subs)
caption=
fontsize=30

# parse command line flags
while true; do
    if [[ $1 == "-v" ]]; then
        shift; verbose=true
    elif [[ $1 == "-gifsicle" ]]; then
        shift; gifsicle=true
    elif [[ $1 == "-scale" ]]; then
        shift; scale=$1; shift
    elif [[ $1 == "-fps" ]]; then
        shift; fps=$1; shift
    elif [[ $1 == "-start" ]]; then
        shift; start_=$1; shift
    elif [[ $1 == "-finish" ]]; then
        shift; finish=(-to "$1"); shift
    elif [[ $1 == "-nosubs" ]]; then
        shift; nosubs=true
    elif [[ $1 == "-sub-lang" ]]; then
        shift; sublang=$1; shift
    elif [[ $1 == "-autosubs" ]]; then
        shift; subflags=(--write-auto-subs)
    elif [[ $1 == "-caption" ]]; then
        shift; caption=$1; shift
    elif [[ $1 == "-fontsize" ]]; then
        shift; fontsize=$1; shift
    elif [[ $1 == "help" || $1 == "-h" || $1 == "--help" ]]; then
        usage
    else
        break
    fi
done

# if the -v flag has been set, show the commands we're running and let ffmpeg
# output more
ffmpegquiet=(-hide_banner -loglevel error)
ytdlpquiet=(--quiet)
if [ -n "$verbose" ]; then
    set -x
    ffmpegquiet=()
    ytdlpquiet=()
fi

sublangs=()
if [ -n "$sublang" ]; then
    sublangs=(--sub-langs "$sublang")
fi

# check for our dependencies, and suggest where to get them if they're not found
if ! command -v ffmpeg &> /dev/null
then
    printf "\033[31mYou must install ffmpeg\033[0m: https://ffmpeg.org/download.html\n\n"
    usage
fi

if ! command -v yt-dlp &> /dev/null
then
    printf "\033[31mYou must install yt-dlp\033[0m: https://github.com/yt-dlp/yt-dlp#installation\n\n"
    usage
fi
if [ -n "$gifsicle" ]; then
    if ! command -v gifsicle &> /dev/null
    then
        printf "\033[31mYou must install gifsicle\033[0m: https://www.lcdf.org/gifsicle/\n\n"
        usage
    fi
fi

# there should be two arguments remaining: the youtube URL and the output file name
if [ $# -lt 2 ]; then
    usage
fi

yturl=$1
output=$2

CUR=$(pwd)
TMP=$(mktemp -d -t "$output")
cd "$TMP"
function finish {
    cd - > /dev/null
}
trap finish EXIT

ytgif_cache_folder="/tmp/ytgif_cache"
if [ ! -d $ytgif_cache_folder ]; then
    mkdir $ytgif_cache_folder
fi

# when we try to expand a subtitle file glob, we want the expanded array to be
# empty if there are no subs available
# https://unix.stackexchange.com/a/34012
shopt -s nullglob

# sanitize string to use it as our cache key - keep only ascii a-zA-Z0-9
yturl_clean=${yturl//[^a-zA-Z0-9]/}

# store the video in the cache folder, in the format video_<sanitized url>.ext
ytdl_video_outfile="$ytgif_cache_folder/video_$yturl_clean.%(ext)s"

# store the subtitles in the cache folder, in the format sub_<sanitized url>.ext
ytdl_sub_outfile="$ytgif_cache_folder/sub_$yturl_clean"

# check for cached video; if one does not exist, download the video
input_video=("$ytgif_cache_folder/video_$yturl_clean".*)
if [ ${#input_video[@]} -eq 0 ]; then
    if ! yt-dlp -f bv \
        "${ytdlpquiet[@]}" \
        "${sublangs[@]}" \
        "${subflags[@]}" \
        -o "$ytdl_video_outfile" \
        -o "subtitle:$ytdl_sub_outfile" \
        "$yturl"; then
        printf "\033[31mfailed running yt-dlp\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
fi

# evaluate the glob to get the input video and subtitle files
input_video=("$ytgif_cache_folder/video_$yturl_clean".*)
subtitles=("$ytgif_cache_folder/sub_$yturl_clean."*)

# if we don't have any subtitles available, just encode to gif without them
if [ -n "$caption" ]; then
    # to avoid the nightmare of quoting bash strings, dump the caption into a
    # text file and use the `textfile` option to ffmpeg
    echo "$caption" > cap.txt

    if ! ffmpeg "${ffmpegquiet[@]}" \
        -ss "$start_" \
        "${finish[@]}" \
        -copyts \
        -i "${input_video[0]}" \
        -filter_complex "\
          [0:v] fps=$fps, \
          scale=$scale:-1, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse, \
          drawtext=borderw=1: \
                   bordercolor=white: \
                   fontcolor=#111111: \
                   fontsize=$fontsize: \
                   x=(w-text_w)/2: \
                   y=(h-text_h)-10: \
                   textfile=cap.txt" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
elif [ ${#subtitles[@]} -eq 0 ] || [ -n "$nosubs" ]; then
    if ! ffmpeg "${ffmpegquiet[@]}" \
        -ss "$start_" \
        "${finish[@]}" \
        -i "${input_video[0]}" \
        -filter_complex "\
          [0:v] fps=$fps, \
          scale=$scale:-1, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
else
    # if fontsize has been set, add a "force_style" with the specified font
    # size
    #
    # https://www.ffmpeg.org/ffmpeg-filters.html#subtitles-1
    force_style=
    if [ -n "$fontsize" ]; then
        force_style=":force_style='FontSize=$fontsize'"
    fi

    # we include -ss and finish twice because we need to tell ffmpeg to
    # properly normalize the timestamps it uses for the subtitles. Honestly I
    # just throw more and more flags at ffmpeg until something like what I want
    # comes out the other side
    # see https://video.stackexchange.com/a/30046
    if ! ffmpeg "${ffmpegquiet[@]}" \
        -ss "$start_" \
        "${finish[@]}" \
        -copyts \
        -i "${input_video[0]}" \
        -filter_complex "\
          [0:v] fps=$fps, \
          scale=$scale:-1, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse, \
          subtitles=${subtitles[0]}${force_style}" \
        -ss "$start_" \
        "${finish[@]}" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
fi

if [ -n "$gifsicle" ]; then
    if ! gifsicle --batch -O2 "$output"; then
        printf "\033[31mfailed running gifsicle\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
fi

cp "$output" "$CUR/"

echo "created $CUR/$output"
