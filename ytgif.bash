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

  -v:              print more verbose output
  -trimborders     automatically trim letterbox borders
  -scale n:        scale the video's width to n pixels [default 640]
  -fps n:          set the fps of the output gif [default 20]
  -gifsicle:       post-process the image with `gifsicle -O2`
  -start time:     the time to start the video at
  -finish time:    the time to finish the video at
  -trim <segment>: comma-separated time to trim from the middle. ex: -trim :40,:49. This is in the timeframe of the clipped video, not the original
  -nosubs:         do not include subtitles in the output even if they're available
  -sub-lang lang:  sub language to choose
  -autosubs:       prefer youtube's auto-generated subtitles
  -caption text:   use a caption for the entire gif instead of subtitles
  -fontsize:       the font size for the caption. Defaults to 30 if caption set, otherwise to whatever ffmpeg defaults it to
  -whisper:        use OpenAI's `whisper` to generate captions
  -whisper-large:  use whisper's "large" model instead of its medium one. May download a large model file

TIME

  The start and finish times can be specified in seconds, or mm:ss or hh:mm:ss.ms. ffmpeg is flexible in what it accepts. https://trac.ffmpeg.org/wiki/Seeking

INSTALLING

  copy ytgif.bash to somewhere on your $PATH and rename it `ytgif`

WHISPER

  For instructions on installing OpenAI whisper, go to https://github.com/openai/whisper#setup

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

Create a gif of Dr. Frankenstein, and use OpenAI whisper to caption it

  ytgif -start 49 -finish 55.5 -whisper \
    https://www.youtube.com/watch?v=WamF64GFPzg frankenstein.gif

See more examples here: https://github.com/llimllib/ytgif/blob/main/docs/examples.md

NOTES

- Be careful to quote the youtube URL, if it contains the & character it will not work unless quoted
- ytgif caches downloaded videos in `/tmp/ytgif_cache`, so you can quickly try edits to the gif without re-downloading videos. These can be quite large, so you may want to clear that folder when you're done making a gif
- youtube's auto subtitles are far from perfect, but often better than nothing
- generating a gif using OpenAI whisper is a bit slow, be patient
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
audiorequired=
caption=
fontsize=30
custom_fontsize=
whisper=
whisper_options=()
trimborders=
trim=

if [ -z "${1:-}" ]; then
    usage
fi

# parse command line flags
while true; do
    case $1 in
        -v)
            verbose=true
            shift
        ;;
        -gifsicle)
            gifsicle=true
            shift
        ;;
        -scale)
            scale=$2
            shift 2
        ;;
        -fps)
            fps=$2
            shift 2
        ;;
        -start)
            start_=$2
            shift 2
        ;;
        -finish)
            finish=(-to "$2")
            shift 2
        ;;
        -sub-lang)
            sublang=$2
            shift 2
        ;;
        -nosubs)
            subflags=(--no-write-subs)
            nosubs="true"
            shift
        ;;
        -autosubs)
            subflags=(--write-auto-subs)
            shift
        ;;
        -caption)
            caption=$2
            shift 2
        ;;
        -fontsize)
            fontsize=$2
            custom_fontsize="true"
            shift 2
        ;;
        -whisper)
            audiorequired="true"
            whisper="true"
            shift
        ;;
        -whisper-large)
            audiorequired="true"
            whisper="true"
            whisper_options=(--model large)
            shift
        ;;
        -trim)
            trim=$2
            shift 2
        ;;
        -trimborders)
            trimborders="true"
            shift
        ;;
        help|-h|--help)
            usage
        ;;
        *)
            break
        ;;
    esac
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
if [ -n "$whisper" ]; then
    if ! command -v whisper &> /dev/null
    then
        printf "\033[31mYou must install whisper\033[0m: https://github.com/openai/whisper\n\n"
        usage
    fi
fi

# there should be two arguments remaining: the youtube URL and the output file name
if [ $# -lt 2 ]; then
    usage
fi

yturl=$1
output=$2

ytgif_cache_folder="/tmp/ytgif_cache"
if [ ! -d $ytgif_cache_folder ]; then
    mkdir $ytgif_cache_folder
fi

# when we try to expand a subtitle file glob, we want the expanded array to be
# empty if there are no subs available
# https://unix.stackexchange.com/a/34012
shopt -s nullglob

###########################
# download.
#
# - download the video into a file called video_<youtube_url>.ext
#   - ext is *usually* webm but we can't be sure
# - download the audio if necessary
# - right now we don't explicitly check for the subs file and download it if we
#   need it - clear your cache if you need this. Sorry
###########################

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

# if $audiorequired is false, this variable will go unused
ytdl_audio_outfile="$ytgif_cache_folder/audio_$yturl_clean.%(ext)s"

# check for cached audio; if one does not exist, download the audio
input_audio=("$ytgif_cache_folder/audio_$yturl_clean".*)
if [ -n "$audiorequired" ] && [ ${#input_audio[@]} -eq 0 ]; then
    if ! yt-dlp -f ba \
        "${ytdlpquiet[@]}" \
        -o "$ytdl_audio_outfile" \
        "$yturl"; then
        printf "\033[31mfailed running yt-dlp\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
fi

# evaluate the glob to get the input video, audio, and subtitle files
input_video=("$ytgif_cache_folder/video_$yturl_clean".*)
input_audio=("$ytgif_cache_folder/audio_$yturl_clean".*)
subtitles=("$ytgif_cache_folder/sub_$yturl_clean."*)

if [ -n "$verbose" ]; then
    printf "\n⚠️  input_video: %s\n⚠️  subtitles: %s\n⚠️  audio: %s\n\n" "${input_video[@]}" "${subtitles[@]}" "${input_audio[@]}"
fi

###########################
# clip files
# - clip the video file to the specified timing and save it as vclip_<youtube_url>.ext
# - if present, clip the audio file too and save as aclip_<youtube_url>.ext
#
# I have been unable to get accurate seeking unless I re-encode the files, so I
# do not have -c copy set. This goes slowly and kind of sucks, but sometimes so
# does life I guess
###########################
ext=${input_video##*.}
vclipfile="$ytgif_cache_folder/vclip_$yturl_clean.$ext"
if ! ffmpeg -y "${ffmpegquiet[@]}" \
    -i "${input_video[0]}" \
    -ss "$start_" \
    "${finish[@]}" \
    "$vclipfile"; then
    printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
    exit 1
fi

# if we want to cut a middle section, re-encode the video to cut it out. This
# could potentially go in the prior filter, but would be complex
if [ -n "$trim" ]; then
    trimstart=${trim%,*}
    trimend=${trim#*,}
    trimtmp="$(mktemp).$ext"
    # can I skip the setpts bit?
    # ffmpeg -i input.mp4 -vf select='not(between(t,10,12))',setpts=N/FRAME_RATE/TB -af aselect='not(between(t,10,12))',asetpts=N/SR/TB out.mp4
    if ! ffmpeg -y "${ffmpegquiet[@]}" \
        -i "$vclipfile" \
        -vf select="not(between(t\,$trimstart\,$trimend))",setpts=N/FRAME_RATE/TB \
        "$trimtmp"; then
        printf "\033[31mfailed trimming middle section. \033[0m\nre-running with -v may show why\n"
        rm -f "$trimtmp"
        exit 1
    fi
    mv "$trimtmp" "$vclipfile"
    rm -f "$trimtmp"
fi

if [ -n "$audiorequired" ]; then
    ext=${input_audio##*.}
    aclipfile="$ytgif_cache_folder/aclip_$yturl_clean.$ext"
    # if we don't include the duplicate start and finish here, we get a clip that
    # is clipped properly but the timing is wrong, it doesn't trim the start time
    # of the file for reasons that are not clear to me
    if ! ffmpeg -y "${ffmpegquiet[@]}" \
        -i "${input_audio[0]}" \
        -ss "$start_" \
        "${finish[@]}" \
        "$aclipfile"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi

    # if we want to cut a middle section, re-encode the audio to cut it out
    if [ -n "$trim" ]; then
        trimstart=${trim%,*}
        trimend=${trim#*,}
        trimtmp="$(mktemp).$ext"
        if ! ffmpeg -y "${ffmpegquiet[@]}" \
            -i "$aclipfile" \
            -af aselect="not(between(t\,$trimstart\,$trimend))",asetpts=N/SR/TB \
            "$trimtmp"; then
            printf "\033[31mfailed trimming middle section. \033[0m\nre-running with -v may show why\n"
            rm -f "$trimtmp"
            exit 1
        fi
        mv "$trimtmp" "$aclipfile"
        rm -f "$trimtmp"
    fi
fi

###########################
# detect crop parameters if requested
###########################

crop=
if [ -n "$trimborders" ]; then
    # use the 'cropdetect' filter to give us a crop parameter for future use in
    # a filter chain. Give it a trailing comma so that it can be used in the chain
    crop="$(ffmpeg -ss 0 -i "$vclipfile" \
                    -vframes 2 \
                    -vf cropdetect \
                    -f null - 2>&1 |
                    awk '/crop/ { print $NF }' |
                    head -n1),"
fi

###########################
# create output file
###########################
if [ -n "$whisper" ]; then
    # run whisper to extract the subtitles
    # add --model large to run the biggest model
    # TODO: add option to use model size
    # if ! whisper "$aclipfile" -o "$ytgif_cache_folder" ; then
    if ! whisper "${whisper_options[@]}" \
        "$aclipfile" \
        -o "$ytgif_cache_folder" \
        --output_format srt ; then
        printf "\033[31mfailed running whisper\033[0m\nre-running with -v may show why\n"
        exit 1
    fi

    subtitle="$ytgif_cache_folder/aclip_$yturl_clean.srt"

    # if fontsize has been set, add a "force_style" with the specified font
    # size
    #
    # https://www.ffmpeg.org/ffmpeg-filters.html#subtitles-1
    force_style=
    if [ -n "$custom_fontsize" ] && [ -n "$fontsize" ]; then
        force_style=":force_style='FontSize=$fontsize'"
    fi

    # convert the clipfile to a gif, using the subtitles we created with
    # whisper
    if ! ffmpeg -y "${ffmpegquiet[@]}" \
        -i "$vclipfile" \
        -filter_complex "\
          [0:v] fps=$fps, \
          $crop \
          scale=$scale:-1:flags=lanczos, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse, \
          subtitles=$subtitle${force_style}" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
elif [ -n "$caption" ]; then
    caption_file="$ytgif_cache_folder/caption_$yturl_clean"

    # to avoid the nightmare of quoting bash strings, dump the caption into a
    # text file and use the `textfile` option to ffmpeg
    echo "$caption" > "$caption_file"

    if ! ffmpeg -y "${ffmpegquiet[@]}" \
        -i "${vclipfile}" \
        -filter_complex "\
          [0:v] fps=$fps, \
          $crop \
          scale=$scale:-1:flags=lanczos, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse, \
          drawtext=borderw=1: \
                   bordercolor=black: \
                   fontcolor=white: \
                   fontsize=$fontsize: \
                   x=(w-text_w)/2: \
                   y=(h-text_h)-10: \
                   textfile=$caption_file" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
# if we don't have any subtitles available, just encode to gif without them
elif [ ${#subtitles[@]} -eq 0 ] || [ -n "$nosubs" ]; then
    if ! ffmpeg -y "${ffmpegquiet[@]}" \
        -i "${vclipfile}" \
        -filter_complex "\
          [0:v] fps=$fps, \
          $crop \
          scale=$scale:-1:flags=lanczos, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
# we have a subtitle file downloaded from youtube
else
    # if fontsize has been set, add a "force_style" with the specified font
    # size
    #
    # https://www.ffmpeg.org/ffmpeg-filters.html#subtitles-1
    force_style=
    if [ -n "$custom_fontsize" ] && [ -n "$fontsize" ]; then
        force_style=":force_style='FontSize=$fontsize'"
    fi

    # we include -ss and finish twice because we need to tell ffmpeg to
    # properly normalize the timestamps it uses for the subtitles. Honestly I
    # just throw more and more flags at ffmpeg until something like what I want
    # comes out the other side
    # see https://video.stackexchange.com/a/30046
    if ! ffmpeg -y "${ffmpegquiet[@]}" \
        -i "${vclipfile}" \
        -filter_complex "\
          [0:v] fps=$fps, \
          $crop \
          scale=$scale:-1:flags=lanczos, \
          split [a][b], \
          [a] palettegen [p], \
          [b][p] paletteuse, \
          subtitles=${subtitles[0]}${force_style}" \
        "$output"; then
        printf "\033[31mfailed running ffmpeg\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
fi

###########################
# Step 3: optimize the file if requested
###########################
if [ -n "$gifsicle" ]; then
    if ! gifsicle --batch -O2 "$output"; then
        printf "\033[31mfailed running gifsicle\033[0m\nre-running with -v may show why\n"
        exit 1
    fi
fi

echo "created $output"
