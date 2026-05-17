#!/bin/zsh
set -euo pipefail

ROOT="/Users/nshum/radial26.github.io"
OUTDIR="$ROOT/video_build/output"
SEGDIR="$OUTDIR/segments_landscape"
CAPTIONDIR="$OUTDIR/captions_landscape"
CAPTIONSCALED="$OUTDIR/captions_landscape_scaled"
CONCATTXT="$OUTDIR/concat_landscape.txt"
CAPTIONCONCAT="$OUTDIR/caption_overlay_concat_landscape.txt"
BASEVIDEO="$OUTDIR/base_video_landscape.mp4"
OVERLAYMOV="$OUTDIR/caption_overlay_landscape.mov"
MUSIC="$OUTDIR/radial_vibe_bed.wav"
FINAL="$ROOT/radial_mutual_interest_reel.mp4"

WIDTH=1920
HEIGHT=1080
FPS=30
TOTAL_DURATION=49.5

mkdir -p "$SEGDIR" "$CAPTIONDIR" "$CAPTIONSCALED"

if [[ "${SKIP_SEGMENTS:-0}" != "1" ]]; then
  find "$SEGDIR" -type f -name '*.mp4' -delete
  rm -f "$CONCATTXT" "$BASEVIDEO"
fi

rm -f "$OVERLAYMOV" "$CAPTIONCONCAT" "$MUSIC" "$FINAL"
find "$CAPTIONDIR" -type f \( -name '*.txt' -o -name '*.png' \) -delete
find "$CAPTIONSCALED" -type f -name '*.png' -delete

clips=(
  "/Users/nshum/Downloads/14347111_3840_2160_60fps.mp4|0.4|3.5|01"
  "/Users/nshum/Downloads/14347129_3840_2160_60fps.mp4|0.2|3.5|02"
  "/Users/nshum/Downloads/14351624_3840_2160_60fps.mp4|0.3|3.5|03"
  "/Users/nshum/Downloads/5379003-uhd_4096_2160_25fps.mp4|6.6|3.5|04"
  "/Users/nshum/Downloads/8402431-uhd_3840_2160_25fps.mp4|0.4|3.0|05"
  "/Users/nshum/Downloads/14351624_3840_2160_60fps.mp4|4.1|3.0|06"
  "/Users/nshum/Downloads/12081817_3840_2160_25fps.mp4|0.1|4.0|07"
  "/Users/nshum/Downloads/7269648-uhd_3840_2160_25fps.mp4|0.8|6.0|08"
  "/Users/nshum/Downloads/5529328-hd_1920_1080_30fps.mp4|0.8|4.0|09"
  "/Users/nshum/Downloads/5701108-uhd_3840_2160_25fps.mp4|0.5|4.0|10"
  "/Users/nshum/Downloads/6145395-uhd_3840_2160_24fps.mp4|7.5|4.0|11"
  "/Users/nshum/Downloads/6321254-uhd_4096_2160_25fps.mp4|0.8|4.0|12"
  "/Users/nshum/Downloads/9810152-uhd_4096_2160_25fps.mp4|0.8|3.5|13"
)

caption_specs=(
  $'0.00|3.50|01|We notice people all the time.'
  $'3.50|7.00|02|Someone at a cafe.'
  $'7.00|10.50|03|Beside us at the airport gate.'
  $'10.50|14.00|04|Across the room at a packed party.'
  $'14.00|17.00|05|Sometimes it\'s attraction.'
  $'17.00|20.00|06|Sometimes it\'s curiosity.'
  $'20.00|24.00|07|Sometimes it\'s just a sense you\'d get along.'
  $'24.00|30.00|08|The people who shape our lives often start as strangers nearby.'
  $'30.00|40.00|09|Radial helps you know when the interest to connect is mutual with the people around you'
  $'40.00|49.50|10|so starting the conversation feels more natural than ever before.'
)

if [[ "${SKIP_SEGMENTS:-0}" != "1" ]]; then
  : > "$CONCATTXT"
  for spec in "${clips[@]}"; do
    IFS='|' read -r src start dur name <<< "$spec"
    out="$SEGDIR/$name.mp4"
    fade_out_start=$(awk -v d="$dur" 'BEGIN { printf "%.2f", d - 0.18 }')

    /opt/homebrew/bin/ffmpeg -y \
      -ss "$start" -t "$dur" -i "$src" \
      -an \
      -filter_complex "[0:v]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT},fps=${FPS},eq=saturation=0.42:brightness=-0.03:contrast=1.06,colorbalance=rs=-0.01:gs=-0.01:bs=0.02,fade=t=in:st=0:d=0.12,fade=t=out:st=${fade_out_start}:d=0.18,setsar=1,format=yuv420p[v]" \
      -map "[v]" \
      -c:v libx264 \
      -preset medium \
      -crf 20 \
      -movflags +faststart \
      "$out"

    printf "file '%s'\n" "$out" >> "$CONCATTXT"
  done

  /opt/homebrew/bin/ffmpeg -y \
    -f concat -safe 0 -i "$CONCATTXT" \
    -c copy \
    "$BASEVIDEO"
fi

for spec in "${caption_specs[@]}"; do
  IFS='|' read -r start end name text <<< "$spec"
  txt="$CAPTIONDIR/$name.txt"
  print -r -- "$text" > "$txt"
done

swift "$ROOT/video_build/render_caption_cards.swift" \
  "$CAPTIONDIR" \
  "$WIDTH" \
  "$HEIGHT" \
  "HelveticaNeue-Light" \
  "40" \
  "1560" \
  "64" >/dev/null

for f in "$CAPTIONDIR"/*.png; do
  base=$(basename "$f")
  /opt/homebrew/bin/ffmpeg -y -i "$f" -vf "scale=${WIDTH}:${HEIGHT}" "$CAPTIONSCALED/$base" >/dev/null 2>&1
done

cat > "$CAPTIONCONCAT" <<EOF
file '$CAPTIONSCALED/01.png'
duration 3.5
file '$CAPTIONSCALED/02.png'
duration 3.5
file '$CAPTIONSCALED/03.png'
duration 3.5
file '$CAPTIONSCALED/04.png'
duration 3.5
file '$CAPTIONSCALED/05.png'
duration 3
file '$CAPTIONSCALED/06.png'
duration 3
file '$CAPTIONSCALED/07.png'
duration 4
file '$CAPTIONSCALED/08.png'
duration 6
file '$CAPTIONSCALED/09.png'
duration 10
file '$CAPTIONSCALED/10.png'
duration 9.5
file '$CAPTIONSCALED/10.png'
EOF

/opt/homebrew/bin/ffmpeg -y \
  -f concat -safe 0 -i "$CAPTIONCONCAT" \
  -vf "fps=${FPS},format=argb" \
  -c:v qtrle \
  "$OVERLAYMOV"

/opt/homebrew/bin/ffmpeg -y \
  -f lavfi -i "aevalsrc=0.10*sin(2*PI*110*t)+0.05*sin(2*PI*220*t)+0.03*sin(2*PI*329.63*t)+0.02*sin(2*PI*440*t):s=48000:d=${TOTAL_DURATION}" \
  -f lavfi -i "anoisesrc=color=pink:amplitude=0.004:d=${TOTAL_DURATION}:r=48000" \
  -filter_complex "[0:a]lowpass=f=1400,volume=0.9[a0];[1:a]highpass=f=180,lowpass=f=1000,volume=0.25[a1];[a0][a1]amix=inputs=2:weights='1 0.35',aecho=0.8:0.6:36|72:0.18|0.10,volume=0.65[aout]" \
  -map "[aout]" \
  -c:a pcm_s16le \
  "$MUSIC"

/opt/homebrew/bin/ffmpeg -y \
  -i "$BASEVIDEO" \
  -i "$OVERLAYMOV" \
  -i "$MUSIC" \
  -filter_complex "[0:v]setsar=1[base];[1:v]format=rgba[ol];[base][ol]overlay[vout]" \
  -map "[vout]" \
  -map 2:a \
  -shortest \
  -c:v libx264 \
  -preset medium \
  -crf 20 \
  -c:a aac \
  -b:a 192k \
  -movflags +faststart \
  "$FINAL"

echo "$FINAL"
