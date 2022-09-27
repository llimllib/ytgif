#!/usr/bin/env bash

set -euo pipefail

# when we try to expand a subtitle file glob, we want the expanded array to be
# empty if there are no subs available
# https://unix.stackexchange.com/a/34012
shopt -s nullglob

function usage() {
        cat <<"EOF"
Usage: ytgif [OPTIONS] <youtube-url> <output_file>

Download the video named in youtube-url and create a gif of it. Will embed the auto-generated subtitles if they're available. Start and finish times should be in ffmpeg format.

OPTIONS

  -v:             print more verbose output
  -scale n:       scale the video's with to n pixels [default 640]
  -fps n:         set the fps of the output gif [default 20]
  -gifsicle:      post-process the image with `gifsicle -O2`
  -start time:    the time to start the video at
  -finish time:   the time to finish the video at
  -nosubs:        do not include subtitles in the outputeven if they're available
  -sub-lang lang: sub language to choose

TIME

    The start and finish times can be specified in seconds, or mm:ss or hh:mm:ss.ms. ffmpeg is flexible in what it accepts. https://trac.ffmpeg.org/wiki/Seeking

INSTALLING

    copy ytgif.bash to somewhere on your $PATH and rename it `ytgif`

EXAMPLES

Download the "I can't believe you've done this" clip, and turn the whole thing into "donethis.gif"

    ytgif "https://www.youtube.com/watch?v=wKbU8B-QVZk" "donethis.gif"

Download the "don't call me shirley" clip from youtube, cut from 1:00 to 1:11.5, lower the fps to 10, and save it as airplane.gif:

    ytgif -start 1:00 -finish 1:11.5 -fps 10 \
        "https://www.youtube.com/watch?v=ixljWVyPby0" "airplane.gif"

Download a bit of a linear algebra lecture, and subtitle it in spanish:

    ytgif -sub-lang es -start 26:54 -finish 27:02 \
        "https://www.youtube.com/watch?v=QVKj3LADCnA" "strang.gif"

Create a tiny rickroll gif, optimize it, and don't include subtitles:

    ytgif -gifsicle -scale 30 -start 0.5 -finish 3 -nosubs \
       "https://www.youtube.com/watch?v=dQw4w9WgXcQ" "rickroll.gif"

NOTES

- Be careful to quote the youtube URL, if it contain the & character it will not work unless quoted
EOF
        exit 1
}

verbose=
gifsicle=
scale=640
fps=20
start_=0
finish=
nosubs=
sublang=

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
        shift; finish=$1; shift
    elif [[ $1 == "-nosubs" ]]; then
        shift; nosubs=true
    elif [[ $1 == "-sub-lang" ]]; then
        shift; sublang=$1; shift
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

if [ -n "$finish" ]; then
    finish="-to $finish"
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

# TODO: ability to provide custom subtitles?
# TODO: ability to customize font and subtitle placement?
if ! yt-dlp -f bv \
    "${ytdlpquiet[@]}" \
    "${sublangs[@]}" \
    --write-subs \
    --write-auto-subs \
    --external-downloader ffmpeg \
    --external-downloader-args "ffmpeg_i:-ss $start_ $finish" \
    -o "$output.webm" \
    "$yturl"; then
    printf "\033[31mfailed running yt-dlp\033[0m\nre-running with -v may show why\n"
    exit 1
fi

# TODO: better way to calculate the subtitle file name? Would be ideal if I
#       could get yt-dlp to tell me where it is somehow
subtitles=(*.vtt)
# if we don't have any subtitles available, just encode to gif without them
if [ ${#subtitles[@]} -eq 0 ] || [ -n "$nosubs" ]; then
    if ! ffmpeg "${ffmpegquiet[@]}" \
        -i "$output.webm" \
        -filter_complex "[0:v] fps=$fps,scale=$scale:-1,split [a][b];[a] palettegen [p];[b][p] paletteuse" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
else
    if ! ffmpeg "${ffmpegquiet[@]}" \
        -i "$output.webm" \
        -filter_complex "[0:v] fps=$fps,scale=$scale:-1,split [a][b];[a] palettegen [p];[b][p] paletteuse,subtitles=${subtitles[0]}" \
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
