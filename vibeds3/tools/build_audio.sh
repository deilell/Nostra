#!/bin/bash
# 诡异不安 音轨生成 —— ffmpeg lavfi 合成（48kHz / 16bit / stereo）
#
# 信号构成：
#   ① 低频主体 : 33Hz + 33.55Hz 双正弦（0.55Hz 拍频，每 1.8 秒一次涨落）
#                + 82.4 / 82.896 / 83.06 Hz 三层微失谐正弦（低频"嗡"的实体）
#   ② 缓慢呼吸 : 0.07Hz / 0.045Hz / 0.031Hz 超低频 LFO 调制各层振幅
#   ③ 非谐泛音 : 61.7Hz × [4.213, 6.794, 9.117] 无理数比率 -> 耳压 / 金属摩擦感
#   ④ 噪声电流 : pink noise 带通 180~2200Hz + 2.4kHz 漂移窄带啸叫
#   ⑤ 空间     : aecho 多抽头 + 高低通，制造"房间比想象中大"
#   ⑥ 动态     : 3s 渐入 / 末 4s 渐出
#
# 用法: ./build_audio.sh <时长秒> <输出.wav>
set +e
DUR="${1:-56}"
OUT="${2:-/tmp/drone.wav}"
SR=48000

command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg not found"; exit 1; }

echo "=== synth ${DUR}s @ ${SR}Hz -> ${OUT} ==="

COMMON="0.50*sin(2*PI*33*t)*(0.55+0.45*sin(2*PI*0.07*t))+0.50*sin(2*PI*33.55*t)*(0.55+0.45*sin(2*PI*0.07*t))+0.28*sin(2*PI*82.4*t)*(0.60+0.40*sin(2*PI*0.045*t))+0.26*sin(2*PI*82.896*t)*(0.60+0.40*sin(2*PI*0.045*t))+0.20*sin(2*PI*83.06*t)*(0.60+0.40*sin(2*PI*0.031*t))+0.045*sin(2*PI*61.7*4.213*t)*(0.5+0.5*sin(2*PI*0.09*t))+0.035*sin(2*PI*61.7*6.794*t)*(0.5+0.5*sin(2*PI*0.11*t))+0.025*sin(2*PI*61.7*9.117*t)*(0.5+0.5*sin(2*PI*0.13*t))"

FADEOUT_ST=$(awk "BEGIN{printf \"%.2f\", $DUR-4.0}")

ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "aevalsrc='${COMMON}':s=${SR}:d=${DUR}" \
  -f lavfi -i "anoisesrc=color=pink:sample_rate=${SR}:duration=${DUR}:amplitude=0.25" \
  -f lavfi -i "aevalsrc='0.13*sin(2*PI*(2400+900*sin(2*PI*0.013*t))*t)*pow(0.5+0.5*sin(2*PI*0.31*t)\,7)':s=${SR}:d=${DUR}" \
  -filter_complex "[0:a]volume=0.9[drone];[1:a]highpass=f=180,lowpass=f=2200,volume=0.30[noise];[2:a]volume=0.45[whine];[drone][noise][whine]amix=inputs=3:weights=1 1 1:normalize=0[mix];[mix]aecho=0.8:0.55:60|140|290:0.40|0.26|0.15,lowpass=f=5200,highpass=f=22,afade=t=in:st=0:d=3.0:curve=esin,afade=t=out:st=${FADEOUT_ST}:d=4.0:curve=esin,volume=1.3[out]" \
  -map "[out]" -ac 2 -ar ${SR} -c:a pcm_s16le "${OUT}" 2>&1

RC=$?
if [ $RC -ne 0 ]; then echo "FFMPEG FAILED rc=$RC"; exit $RC; fi

ls -l "${OUT}"
ffprobe -hide_banner -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,sample_rate,channels -of default=noprint_wrappers=1 "${OUT}"
echo "=== done ==="