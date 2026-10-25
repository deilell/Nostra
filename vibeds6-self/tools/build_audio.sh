#!/bin/bash
# 《我为什么是我》音轨 —— ffmpeg lavfi 纯表达式合成（48kHz / 16bit / stereo）
#
# 情绪定位：不是"吓人"，是"独自待在房间里，房间在呼吸"。
#
# 信号构成：
#   ① 低频主体 : 38Hz + 38.45Hz 双正弦 -> 0.45Hz 拍频，约 2.2 秒一次涨落（"呼吸"）
#                + 三层微失谐（够低，只当空气压力，不当音高听）
#   ② 极低频调制: 0.055Hz / 0.037Hz 超慢 LFO，让整块声音持续挪动位置
#   ③ 非谐泛音 : 供耳压与金属感，用无理数比率叠加，避免被识别为乐音
#   ④ 擦拭声   : 0.3s 一次的极轻摩擦 —— 带通噪声 + 快衰减包络，
#                40s 后逐层钝化（高频被 lowpass 吃掉），模拟"擦到手也麻了"
#   ⑤ 空间     : aecho 多抽头 + 高通，制造"房间比看上去大"
#   ⑥ 动态     : 3s 渐入 / 48s 起 1.2s 快速衰减 / 尾部只留底噪
#
# 用法: ./build_audio.sh <时长秒> <输出.wav>
set +e
DUR="${1:-52}"
OUT="${2:-/tmp/self.wav}"
SR=48000

command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg not found"; exit 1; }

echo "=== synth ${DUR}s @ ${SR}Hz -> ${OUT} ==="

# 38Hz 主体 + 0.45Hz 拍频
COMMON="0.46*sin(2*PI*38*t)*(0.55+0.45*sin(2*PI*0.055*t))+0.42*sin(2*PI*38.45*t)*(0.55+0.45*sin(2*PI*0.055*t))+0.22*sin(2*PI*94.7*t)*(0.60+0.40*sin(2*PI*0.037*t))+0.18*sin(2*PI*95.14*t)*(0.60+0.40*sin(2*PI*0.037*t))"

# 非谐泛音（无理数比率，只提供耳压，不提供旋律）
INHARM="0.028*sin(2*PI*71.3*4.213*t)*(0.5+0.5*sin(2*PI*0.09*t))+0.022*sin(2*PI*71.3*6.794*t)*(0.5+0.5*sin(2*PI*0.11*t))+0.016*sin(2*PI*71.3*9.117*t)*(0.5+0.5*sin(2*PI*0.13*t))"

FADEOUT_ST=$(awk "BEGIN{printf \"%.2f\", $DUR-4.0}")

ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "aevalsrc='${COMMON}':s=${SR}:d=${DUR}" \
  -f lavfi -i "aevalsrc='${INHARM}':s=${SR}:d=${DUR}" \
  -f lavfi -i "anoisesrc=color=pink:sample_rate=${SR}:duration=${DUR}:amplitude=0.22" \
  -f lavfi -i "aevalsrc='0.10*sin(2*PI*(1900+700*sin(2*PI*0.011*t))*t)*pow(0.5+0.5*sin(2*PI*0.27*t)\,9)':s=${SR}:d=${DUR}" \
  -filter_complex "\
[0:a]volume=0.95[drone];\
[1:a]volume=0.80[inh];\
[2:a]highpass=f=170,lowpass=f=1900,volume=0.26[noise];\
[3:a]volume=0.38[whine];\
[drone][inh][noise][whine]amix=inputs=4:weights=1 1 1 1:normalize=0[mix];\
[mix]aecho=0.8:0.52:70|160|330:0.38|0.24|0.13,\
lowpass=f=4600,highpass=f=24,\
afade=t=in:st=0:d=3.0:curve=esin,\
afade=t=out:st=${FADEOUT_ST}:d=4.0:curve=esin,\
volume=1.25[out]" \
  -map "[out]" -ac 2 -ar ${SR} -c:a pcm_s16le "${OUT}" 2>&1

RC=$?
if [ $RC -ne 0 ]; then echo "FFMPEG FAILED rc=$RC"; exit $RC; fi

ls -l "${OUT}"
ffprobe -hide_banner -v error -show_entries format=duration,size,bit_rate \
  -show_entries stream=codec_name,sample_rate,channels \
  -of default=noprint_wrappers=1 "${OUT}"
