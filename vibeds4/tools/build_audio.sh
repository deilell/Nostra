#!/usr/bin/env bash
# corridor audio: presence through absence
# dur default 58s. 48kHz stereo pcm_s16le.
set +e

DUR=${1:-58}
OUT=${2:-/tmp/corridor.wav}
SR=48000

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg missing" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")" 2>/dev/null

# ---------- layer 1: HVAC room tone (the floor of the whole piece) ----------
# very low rumble + mid air movement. this is what remains when everything else is cut.
HVAC="0.055*sin(2*PI*49.5*t)+0.045*sin(2*PI*50.2*t)+0.030*sin(2*PI*98.7*t)"
HVAC="${HVAC}+0.020*sin(2*PI*147.3*t)*(0.5+0.5*sin(2*PI*0.07*t))"

# ---------- layer 2: corridor drone (the thing that gets taken away) ----------
# 41Hz + 41.4Hz beat = 0.4Hz throb (slow, chest-level). plus a 3rd harmonic.
DRONE="0.34*sin(2*PI*41*t)+0.30*sin(2*PI*41.4*t)+0.12*sin(2*PI*82.2*t)"
DRONE="${DRONE}+0.09*sin(2*PI*123.9*t)*(0.5+0.5*sin(2*PI*0.031*t))"

# ---------- layer 3: distance tone (metallic, far away, barely there) ----------
# 2.7kHz with very slow drift, gated by a slow uneven envelope.
FAR="0.030*sin(2*PI*(2700+140*sin(2*PI*0.0089*t))*t)"
FAR="${FAR}*(0.28+0.72*pow(0.5+0.5*sin(2*PI*0.017*t)\,4))"

# ---------- layer 4: air / hiss at very low level (the "tape" floor) ----------
# pink noise, heavily filtered, sits just above silence.

# ---------- the gate curve ----------
# the only event: 24.0 -> 25.2 the drone is cut. it does not come back at full level.
# a second dip 44.0 -> 46.5 as things collapse, then a slow slide to near-silence.
# built from clip() ramps so the expression stays flat (deep if-nesting breaks lavfi eval).
# clamp helper: lavfi has no clip(), build ramp() from min/max
r() { echo "min(1\,max(0\,(t-$1)/$2))"; }
# gate shape:
#   0..23.6   1.00   full drone
#   23.6..24  1.00 -> 0    the cut
#   24..25.2  0           ABSENT (the event)
#   25.2..25.6  0 -> 0.42  it comes back wrong, quieter
#   25.6..44  0.42
#   44..44.4  0.42 -> 0.06  collapses
#   44.4..46.8  0.06
#   46.8..48  0.06 -> 0.20
#   48..54    0.20
#   54..58    0.20 -> 0.02  slides toward nothing
GATE="1"
GATE="${GATE}-$(r 23.6 0.4)"                       # 1 -> 0
GATE="${GATE}+0.42*$(r 25.2 0.4)"                   # 0 -> 0.42
GATE="${GATE}-0.36*$(r 44.0 0.4)"                   # 0.42 -> 0.06
GATE="${GATE}+0.14*$(r 46.8 1.2)"                   # 0.06 -> 0.20
GATE="${GATE}-0.19*$(r 54.0 4.0)"                   # 0.20 -> 0.02
GATE="(${GATE})"
HG="0"
HG="${HG}+0.88*$(r 23.6 0.4)"
HG="${HG}-0.88*$(r 25.2 1.2)"
HG="${HG}+0.30*$(r 44.0 0.5)"
HG="${HG}-0.10*$(r 47.0 1.5)"


ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "aevalsrc='${HVAC}':s=${SR}:d=${DUR}" \
  -f lavfi -i "aevalsrc='${DRONE}':s=${SR}:d=${DUR}" \
  -f lavfi -i "aevalsrc='${FAR}':s=${SR}:d=${DUR}" \
  -f lavfi -i "anoisesrc=color=pink:amplitude=0.06:s=${SR}:d=${DUR}" \
  -filter_complex "\
[0]lowpass=280,highpass=28,volume=1.0,aeval='val(0)*(1-0.88*(${HG}))'[hvac];\
[1]aeval='val(0)*(${GATE})'[droneg];\
[2]aeval='val(0)*(${GATE})'[farg];\
[3]highpass=900,lowpass=7000,volume=0.55[air];\
[droneg]aecho=0.85:0.62:55|131|277|413:0.42|0.30|0.19|0.11[drone];\
[hvac][drone]amix=inputs=2:weights=1 1:normalize=0[base];\
[base]aecho=0.7:0.45:88|197:0.24|0.12[base2];\
[base2][farg][air]amix=inputs=3:weights=1 1 1:normalize=0[pre];\
[pre]lowpass=9000,highpass=24,volume=2.6[mix];\
[mix]afade=t=in:st=0:d=4.0:curve=esin[out]" \
  -map "[out]" -ac 2 -ar ${SR} -c:a pcm_s16le "$OUT"

RC=$?
echo "RC=$RC"
ls -l "$OUT"
ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,sample_rate,channels -of default=noprint_wrappers=1 "$OUT"
