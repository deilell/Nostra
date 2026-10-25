#!/usr/bin/env bash
# vibeds5-room : a room at night. low, quiet, nothing happens.
# usage: build_audio.sh [dur] [out]
set -u
DUR=${1:-72}
OUT=${2:-/tmp/room.wav}
SR=48000

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg missing"; exit 1; }

# --- design notes ---------------------------------------------------------
# sub bed  : 38.6 / 38.9 / 77.2 Hz detuned sines. MUST NOT go through the
#            600 Hz bandpass: that filter sits far above the fundamental and
#            used to eat 13.6 dB. It is kept on its own branch.
# noise    : pink (rain outside) + brown (room air), band-limited, echo tail.
# piano    : four hits, each quieter. no melody, no resolution.
# master   : long fade in / longer fade out, then a single level calibration.
# lavfi    : no clip(). every ramp is min/max with escaped commas.
# --------------------------------------------------------------------------

SUB="0.055*sin(2*PI*38.6*t)+0.042*sin(2*PI*38.9*t)+0.018*sin(2*PI*77.2*t)"
RAINMOD="0.62+0.30*sin(2*PI*0.013*t)+0.08*sin(2*PI*0.041*t)"

ph() {
  echo "$3*exp(-2.2*max(0\,t-$1))*min(1\,max(0\,(t-$1)/0.014))*sin(2*PI*$2*max(0\,t-$1))"
}
P1=$(ph 14.0 164.81 0.070)
P2=$(ph 33.5 146.83 0.056)
P3=$(ph 51.0 130.81 0.046)
P4=$(ph 58.5 123.47 0.038)
PIANO="${P1}+${P2}+${P3}+${P4}"

FADE="min(1\,max(0\,t/9))*min(1\,max(0\,(${DUR}-t)/11))"

ffmpeg -hide_banner -y \
  -f lavfi -i "aevalsrc=${SUB}:s=${SR}:d=${DUR}" \
  -f lavfi -i "anoisesrc=color=pink:s=${SR}:d=${DUR}:a=0.55" \
  -f lavfi -i "anoisesrc=color=brown:s=${SR}:d=${DUR}:a=0.30" \
  -f lavfi -i "aevalsrc=${PIANO}:s=${SR}:d=${DUR}" \
  -filter_complex "\
    [1:a]lowpass=f=1300,highpass=f=260,volume=0.30[rain0];\
    [rain0]aeval=val(0)*(${RAINMOD})[rain];\
    [2:a]lowpass=f=420,highpass=f=40,volume=0.55[air0];\
    [rain][air0]amix=inputs=2:weights=1 1:normalize=0[noise0];\
    [noise0]aecho=0.70:0.45:140|310|540:0.24|0.13|0.07[noise];\
    [noise]bandpass=f=600:width_type=h:w=1800,volume=2.4[noiseb];\
    [0:a]volume=1.15[sub];\
    [sub][noiseb]amix=inputs=2:weights=1 1:normalize=0,volume=2.2[bed];\
    [3:a]aecho=0.70:0.45:220|430:0.26|0.14[piano0];\
    [piano0]volume=4.2[piano];\
    [bed][piano]amix=inputs=2:weights=1 1:normalize=0,aeval=val(0)*(${FADE}),alimiter=limit=0.89:level=false[out]" \
  -map "[out]" -ac 2 -ar ${SR} -c:a pcm_s16le "$OUT" 2>&1 \
  | grep -Ei "error|invalid|missing|unused|no such|matches no streams" | head -8

if [ -f "$OUT" ]; then
  echo "OK $OUT"
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 "$OUT"
  ffprobe -v error -show_entries stream=sample_rate,channels -of default=noprint_wrappers=1 "$OUT"
  ffmpeg -hide_banner -i "$OUT" -af volumedetect -f null /dev/null 2>&1 | grep -E "mean_volume|max_volume"
  ls -l "$OUT"
else
  echo FAILED
fi
