#!/bin/sh
# VGA/audio performance workload plus a fixed-duration Grand Prix integration soak.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=${DOSBOX_ARMV6_PERF_WORKDIR:-/tmp/dosbox-armv6-perf-integration}
runs=${RUNS:-3}; game_seconds=${GP_SECONDS:-180}
game_dir=${GP_DIR:-/home/dietpi/pi-286-game-files/grand-prix}; gp_cycles=${GP_CYCLES:-fixed 3000}
include_normal=${INCLUDE_CUSTOM_NORMAL:-0}
video=${PI286_VIDEO_DRIVER:-fbcon}; audio=${PI286_AUDIO_DRIVER:-alsa}
[ "$runs" -ge 3 ] 2>/dev/null || { echo 'RUNS must be >= 3' >&2; exit 2; }
[ "$game_seconds" -ge 10 ] 2>/dev/null || { echo 'GP_SECONDS must be >= 10' >&2; exit 2; }
[ "$include_normal" = 0 ] || [ "$include_normal" = 1 ] || { echo 'INCLUDE_CUSTOM_NORMAL must be 0 or 1' >&2; exit 2; }
[ -x /usr/bin/dosbox ] || { echo '/usr/bin/dosbox is not installed' >&2; exit 2; }
[ -x "$root/bin/dosbox-normal" ] && [ -x "$root/bin/dosbox-dynrec" ] || { echo 'release is incomplete' >&2; exit 2; }
[ -r "$root/guest/AV-BENCH.COM" ] || { echo 'release lacks AV-BENCH.COM' >&2; exit 2; }
[ -r "$game_dir/GPEGA.EXE" ] || { echo "Grand Prix EGA executable missing: $game_dir/GPEGA.EXE" >&2; exit 2; }
case $gp_cycles in max|fixed\ [0-9]*) ;; *) echo 'GP_CYCLES must be max or fixed <positive-integer>' >&2; exit 2;; esac
case $video in
  fbcon) [ -e /dev/fb0 ] || { echo '/dev/fb0 is unavailable' >&2; exit 2; };;
  dummy) audio=dummy;;
  *) echo "Unsupported PI286_VIDEO_DRIVER: $video (use fbcon or dummy)" >&2; exit 2;;
esac
mkdir -p "$work/logs"; guest="$work/guest"; rm -rf "$guest"; cp -R "$root/guest" "$guest"
echo 'DOSBox ARMv6 integration experiment'
echo "work directory: $work"; echo "video=$video audio=$audio game_seconds=$game_seconds gp_cycles=$gp_cycles include_custom_normal=$include_normal"
echo 'For real VGA/audio and Grand Prix input, launch this from the active tty1 console.'
echo 'custom build provenance:'; sed -n '1,160p' "$root/BUILD-MANIFEST.txt"
run_dosbox() {
  binary=$1 config=$2 log=$3
  SDL_VIDEODRIVER="$video" SDL_AUDIODRIVER="$audio" SDL_FBDEV=/dev/fb0 SDL_FB_BROKEN_MODES=1 \
    LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$binary" -conf "$config" >"$log" 2>&1
}
run_av() {
  name=$1 binary=$2 template=$3; timings="$work/$name.av.times"; : > "$timings"; run=0
  echo "== VGA + PC-speaker COM: $name =="
  while [ "$run" -le "$runs" ]; do
    rm -f "$guest/RESULT.TXT"; sed "s|@GUESTDIR@|$guest|g" "$template" > "$work/$name.av.conf"
    start=$(date +%s%N); run_dosbox "$binary" "$work/$name.av.conf" "$work/logs/$name-av-$run.log"; end=$(date +%s%N)
    result=$(sed -n 's/^PI286_AV_BENCH_RESULT=//p' "$guest/RESULT.TXT" 2>/dev/null | tr -d '\r' | tail -1)
    [ "$result" = AF4A0000 ] || { echo "$name AV checksum '$result' is not expected AF4A0000; see $work/logs/$name-av-$run.log" >&2; exit 1; }
    [ "$run" -gt 0 ] && printf '%s %s\n' "$(( (end-start)/1000000 ))" "$result" | tee -a "$timings"
    run=$((run+1))
  done
}
summarise_av() {
  name=$1; file="$work/$name.av.times"; checks=$(awk '{print $2}' "$file" | sort -u | tr '\n' ' ')
  [ "$(awk '{print $2}' "$file" | sort -u | wc -l | tr -d ' ')" = 1 ] || { echo "$name AV checksum changed: $checks" >&2; exit 1; }
  set -- $(awk '{print $1}' "$file" | sort -n); count=$#; middle=$(( (count+1)/2 )); eval "median=\${$middle}"; max=$(awk '{print $1}' "$file" | sort -n | tail -1)
  echo "$name: timings_ms=[$*] min=$1 median=$median max=$max checksum=$checks"
  case $name in distro) distro_median=$median;; custom-normal) normal_median=$median;; custom-dynrec) dynrec_median=$median;; esac
}
run_gp() {
  name=$1 binary=$2 template=$3; config="$work/$name.gp.conf"; log="$work/logs/$name-gp.log"
  sed -e "s|@GAMEDIR@|$game_dir|g" -e "s|@CYCLES@|$gp_cycles|g" "$template" > "$config"
  echo "== Grand Prix ${game_seconds}s soak: $name =="
  start=$(date +%s%N)
  SDL_VIDEODRIVER="$video" SDL_AUDIODRIVER="$audio" SDL_FBDEV=/dev/fb0 SDL_FB_BROKEN_MODES=1 \
    PI286_SDL_PRESENT_STATS="$work/$name.gp.present.tsv" \
    LD_PRELOAD="$root/lib/libpi286-sdl-present.so${LD_PRELOAD:+:$LD_PRELOAD}" \
    LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$binary" -conf "$config" >"$log" 2>&1 & pid=$!
  sleep 2
  kill -0 "$pid" 2>/dev/null || { echo "$name exited during Grand Prix startup; see $log" >&2; wait "$pid" || :; return 1; }
  sleep $((game_seconds-2))
  ticks=$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo unavailable)
  kill -TERM "$pid" 2>/dev/null || :
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do sleep 1; waited=$((waited+1)); done
  kill -KILL "$pid" 2>/dev/null || :; wait "$pid" || :
  end=$(date +%s%N); elapsed=$(( (end-start)/1000000 )); hz=$(getconf CLK_TCK)
  case $ticks in *[!0-9]*|'') cpu_ms=unavailable;; *) cpu_ms=$((ticks*1000/hz));; esac
  if [ -s "$work/$name.gp.present.tsv" ]; then
    pacing=$(awk 'NR > 1 { frames += $2; windows++; if ($4 > max_gap) max_gap=$4; drops += $6 } END { if (windows) printf "present_fps=%.1f max_gap_ms=%.1f gaps_over_33ms=%d", frames/windows, max_gap/1000, drops; else print "present_stats=none" }' "$work/$name.gp.present.tsv")
  else pacing=present_stats=unavailable; fi
  echo "$name: host_elapsed_ms=$elapsed process_cpu_ms=$cpu_ms $pacing log=$log"
}
run_av distro /usr/bin/dosbox "$root/config/av-normal.conf.in"
if [ "$include_normal" = 1 ]; then run_av custom-normal "$root/bin/dosbox-normal" "$root/config/av-normal.conf.in"; fi
run_av custom-dynrec "$root/bin/dosbox-dynrec" "$root/config/av-dynamic.conf.in"
echo '== VGA + PC-speaker summary: host wall-clock milliseconds =='
summarise_av distro
if [ "$include_normal" = 1 ]; then summarise_av custom-normal; fi
summarise_av custom-dynrec
if [ "$include_normal" = 1 ]; then
  awk -v d="$distro_median" -v n="$normal_median" -v y="$dynrec_median" 'BEGIN { printf "custom-normal vs distro: %.3fx\ncustom-dynrec vs distro: %.3fx\ncustom-dynrec vs custom-normal: %.3fx\n",d/n,d/y,n/y }'
else
  awk -v d="$distro_median" -v y="$dynrec_median" 'BEGIN { printf "custom-dynrec vs distro: %.3fx\n",d/y }'
fi
run_gp distro /usr/bin/dosbox "$root/config/gp-normal.conf.in"
if [ "$include_normal" = 1 ]; then run_gp custom-normal "$root/bin/dosbox-normal" "$root/config/gp-normal.conf.in"; fi
run_gp custom-dynrec "$root/bin/dosbox-dynrec" "$root/config/gp-dynamic.conf.in"
echo 'Grand Prix is an integration soak, not a speed ratio: it runs each variant for the same host-time budget.'
