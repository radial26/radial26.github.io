#!/bin/zsh
set -euo pipefail

ROOT="/Users/nshum/radial26.github.io"
OUTDIR="$ROOT/video_build/output"
SEGDIR="$OUTDIR/segments"
FINAL="$ROOT/radial_mutual_interest_reel.mp4"
CAPTIONDIR="$OUTDIR/captions"

mkdir -p "$SEGDIR"
mkdir -p "$CAPTIONDIR"

if [[ "${SKIP_SEGMENTS:-0}" != "1" ]]; then
  find "$SEGDIR" -type f -name '*.mp4' -delete
  rm -f "$OUTDIR/concat.txt"
fi

rm -f "$FINAL"

clips=(
  "/Users/nshum/Downloads/12081817_3840_2160_25fps.mp4|0.0|4.0|01"
  "/Users/nshum/Downloads/9810152-uhd_4096_2160_25fps.mp4|1.0|4.0|02"
  "/Users/nshum/Downloads/7269648-uhd_3840_2160_25fps.mp4|4.0|4.0|03"
  "/Users/nshum/Downloads/5529328-hd_1920_1080_30fps.mp4|1.0|4.0|04"
  "/Users/nshum/Downloads/5387571-uhd_2160_4096_30fps.mp4|1.0|4.0|05"
  "/Users/nshum/Downloads/5701108-uhd_3840_2160_25fps.mp4|1.5|4.0|06"
  "/Users/nshum/Downloads/6145395-uhd_3840_2160_24fps.mp4|2.0|5.0|07"
  "/Users/nshum/Downloads/8120677-uhd_2160_4096_25fps.mp4|3.0|7.0|08"
  "/Users/nshum/Downloads/5379003-uhd_4096_2160_25fps.mp4|7.0|10.0|09"
  "/Users/nshum/Downloads/14351624_3840_2160_60fps.mp4|2.0|8.0|10"
)

if [[ "${SKIP_SEGMENTS:-0}" != "1" ]]; then
  for spec in "${clips[@]}"; do
    IFS='|' read -r src start dur name <<< "$spec"
    out="$SEGDIR/$name.mp4"
    fade_out_start=$(awk -v d="$dur" 'BEGIN { printf "%.2f", d - 0.35 }')

    /opt/homebrew/bin/ffmpeg -y \
      -ss "$start" -t "$dur" -i "$src" \
      -an \
      -filter_complex "[0:v]split=2[bg][fg];[bg]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=24:12[bg2];[fg]scale=1080:1920:force_original_aspect_ratio=decrease[fg2];[bg2][fg2]overlay=(W-w)/2:(H-h)/2,fade=t=in:st=0:d=0.25,fade=t=out:st=${fade_out_start}:d=0.35,setsar=1,format=yuv420p[v]" \
      -map "[v]" \
      -r 30 \
      -c:v libx264 \
      -preset medium \
      -crf 20 \
      -movflags +faststart \
      "$out"

    printf "file '%s'\n" "$out" >> "$OUTDIR/concat.txt"
  done
fi

caption_specs=(
  $'0.00|4.00|01|We notice people all the time.'
  $'4.00|8.00|02|Someone at a cafe.'
  $'8.00|12.00|03|Beside us at the airport gate.'
  $'12.00|16.00|04|Across the room at a packed party.'
  $'16.00|20.00|05|Sometimes it\'s attraction.'
  $'20.00|24.00|06|Sometimes it\'s curiosity.'
  $'24.00|29.00|07|Sometimes it\'s just a sense\nyou\'d get along.'
  $'29.00|36.00|08|The people who shape our lives\noften start as strangers nearby.'
  $'36.00|46.00|09|Radial helps you know when the interest\nto connect is mutual with the people around you'
  $'46.00|54.00|10|so starting the conversation feels\nmore natural than ever before.'
)

vf_chain="setsar=1"
for spec in "${caption_specs[@]}"; do
  IFS='|' read -r start end name text <<< "$spec"
  txt="$CAPTIONDIR/$name.txt"
  print -r -- "$text" > "$txt"
done

swift "$ROOT/video_build/render_caption_cards.swift" "$CAPTIONDIR" >/dev/null

ffmpeg_inputs=(-f concat -safe 0 -i "$OUTDIR/concat.txt")
filter_complex="[0:v]setsar=1[v0]"
input_index=1
prev_label="v0"

for spec in "${caption_specs[@]}"; do
  IFS='|' read -r start end name text <<< "$spec"
  png="$CAPTIONDIR/$name.png"
  ffmpeg_inputs+=(-loop 1 -i "$png")
  next_label="v${input_index}"
  filter_complex+=";[${prev_label}][${input_index}:v]overlay=enable='between(t,${start},${end})'[$next_label]"
  prev_label="$next_label"
  input_index=$((input_index + 1))
done

ffmpeg_inputs+=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000)
audio_index=$input_index

/opt/homebrew/bin/ffmpeg -y \
  "${ffmpeg_inputs[@]}" \
  -filter_complex "$filter_complex" \
  -map "[$prev_label]" \
  -map "${audio_index}:a" \
  -shortest \
  -c:v libx264 \
  -preset medium \
  -crf 20 \
  -c:a aac \
  -b:a 128k \
  -movflags +faststart \
  "$FINAL"

echo "$FINAL"
