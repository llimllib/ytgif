```sh
ytgif -nosubs -start 5 -finish 11 -fps 15 \
    "https://www.youtube.com/watch?v=JQoNhRN9CiI" moonrise.gif
```

![](gifs/moonrise.gif)

```sh
ytgif -nosubs -start 7 -finish 8 \
    "https://www.youtube.com/watch?v=9vt38aRqUTI" shorts.gif
```

![](gifs/shorts.gif)

```sh
ytgif -start 1:02 -finish 1:11 -fps 10 \
    "https://www.youtube.com/watch?v=ixljWVyPby0" airplane.gif
```

![](gifs/airplane.gif)

```sh
ytgif -start 2:42 -finish 2:45.5 -fontsize 25 \
  -caption "we'll bless 'em all until we get fershnickered" \
  https://www.youtube.com/watch?v=k4v8BVKlAfM drunk.gif
```

![](gifs/drunk.gif)

```sh
ytgif -start 49 -finish 55.5 -whisper \
  https://www.youtube.com/watch?v=WamF64GFPzg frankenstein.gif
```

![](gifs/frankenstein.gif)

```sh
ytgif -start 0:20.2 -finish 0:23.9 -caption "say Hello to my Little Friend" \
    'https://www.youtube.com/watch?v=a_z4IuxAqpE' hello.gif
```

![](gifs/hello.gif)

```sh
ytgif -start 1:58 -finish 1:59.9 -caption "damn you" \
    'https://www.youtube.com/watch?v=tskpXGAJMhw' damn.gif
```

![](gifs/damn.gif)

```sh
./ytgif.bash -start 0:10 -finish 0:14 \
    -caption 'one of the new cover sheets on your TPS report' \
    -fontsize 20 \
    'https://www.youtube.com/watch?v=jsLUidiYm0w' tps.gif
```

![](gifs/tps.gif)

```sh
./ytgif.bash -start 4:14.5 -finish 4:18.5 \
    -fps 12 \
    -caption "let's not argue about about killed who" \
    'https://www.youtube.com/watch?v=btmWWnQ-gAY' \
    bicker.gif
```

![](gifs/bicker.gif)

```sh
./ytgif.bash -whisper-large -start 19 -finish 27 \
    -scale 500 \
    -gifsicle \
    'https://www.youtube.com/watch?v=UQ26GjG69fk' catapult.gif
```

![](gifs/drunk.gif)

```sh
ytgif -start 13 -finish 17 -fontsize 40 \
    -caption "I've made a huge mistake" \
    'https://www.youtube.com/watch?v=GwQW3KW3DCc' mistake.gif
```

![](gifs/mistake.gif)

```sh
ytgif -start 1:42.5 -finish 1:48.5 -trimborders -whisper-large \
    'https://www.youtube.com/watch?v=ZTT1qUswYL0' illinois_nazis.gif
```

![](gifs/illinois_nazis.gif)

```sh
./ytgif.bash -start 1:09 -finish 1:14 -whisper-large \
'https://www.youtube.com/watch?v=Pe5eL8LQdY0' heavystuff.gif
```

![](gifs/heavystuff.gif)

**Trim a middle section out of the gif, from 3 seconds to 11 seconds&**

```sh
./ytgif.bash -start 1:48 -finish 2:02 -trimborders -nosubs \
  -trim 3,11 \
  'https://www.youtube.com/watch?v=LClTjcyNJSI' funeral.gif
```

![](gifs/funeral.gif)
