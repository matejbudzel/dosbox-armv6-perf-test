#!/bin/sh
# Four fixed-cycle Grand Prix pacing runs using only the ARM dynrec binary.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=${DOSBOX_ARMV6_PERF_WORKDIR:-/tmp/dosbox-armv6-gp-dynrec-sweep}
game_dir=${GP_DIR:-/home/dietpi/pi-286-game-files/grand-prix}
game_seconds=${GP_SECONDS:-180}; rates=${GP_CYCLE_RATES:-'2000 2500 3000 3500'}
video=${PI286_VIDEO_DRIVER:-fbcon}; audio=${PI286_AUDIO_DRIVER:-alsa}
[ "$game_seconds" -ge 10 ] 2>/dev/null || { echo 'GP_SECONDS must be >= 10' >&2; exit 2; }
[ -x "$root/bin/dosbox-dynrec" ] || { echo 'dynrec binary is missing' >&2; exit 2; }
[ -r "$root/lib/libpi286-sdl-present.so" ] || { echo 'SDL present tracer is missing' >&2; exit 2; }
[ -r "$root/config/gp-dynamic.conf.in" ] || { echo 'Grand Prix dynrec config is missing' >&2; exit 2; }
[ -r "$game_dir/GPEGA.EXE" ] || { echo "Grand Prix EGA executable missing: $game_dir/GPEGA.EXE" >&2; exit 2; }
case $video in fbcon) [ -e /dev/fb0 ] || { echo '/dev/fb0 is unavailable' >&2; exit 2; };; dummy) audio=dummy;; *) echo 'PI286_VIDEO_DRIVER must be fbcon or dummy' >&2; exit 2;; esac
for rate in $rates; do case $rate in *[!0-9]*|'') echo "Invalid cycle rate: $rate" >&2; exit 2;; esac; done
mkdir -p "$work/logs"
echo 'DOSBox ARMv6 Grand Prix dynrec cycle sweep'
echo "work directory: $work"; echo "video=$video audio=$audio seconds_per_rate=$game_seconds rates=$rates"
echo 'Launch from tty1 for real framebuffer, audio, and keyboard observation.'
sed -n '1,160p' "$root/BUILD-MANIFEST.txt"
summarise_trace() {
  label=$1 file=$2; tail_ms=$3
  awk -v label="$label" -v tail_ms="$tail_ms" '
    NR == 1 { next }
    { end[NR] = $1; frames[NR] = $2; gap[NR] = $4; call[NR] = $5; drops[NR] = $6; last = $1 }
    END {
      for (i = 2; i <= NR; ++i) if (!tail_ms || end[i] >= last-tail_ms) {
        selected++; total += frames[i]; if (gap[i] > maxgap) maxgap = gap[i]; if (call[i] > maxcall) maxcall = call[i]; totaldrops += drops[i]
      }
      if (selected) printf "%s windows=%d present_fps=%.2f max_gap_ms=%.3f max_present_ms=%.3f gaps_over_33ms=%d\n", label, selected, total/selected, maxgap/1000, maxcall/1000, totaldrops
      else print label " present_stats=none"
    }' "$file"
}
for rate in $rates; do
  name="dynrec-fixed-$rate"; config="$work/$name.conf"; trace="$work/$name.present.tsv"; log="$work/logs/$name.log"
  sed -e "s|@GAMEDIR@|$game_dir|g" -e "s|@CYCLES@|fixed $rate|g" "$root/config/gp-dynamic.conf.in" > "$config"
  echo "== $name: ${game_seconds}s =="
  start=$(date +%s%N)
  SDL_VIDEODRIVER="$video" SDL_AUDIODRIVER="$audio" SDL_FBDEV=/dev/fb0 SDL_FB_BROKEN_MODES=1 \
    PI286_SDL_PRESENT_STATS="$trace" LD_PRELOAD="$root/lib/libpi286-sdl-present.so${LD_PRELOAD:+:$LD_PRELOAD}" \
    LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$root/bin/dosbox-dynrec" -conf "$config" >"$log" 2>&1 & pid=$!
  sleep 2
  kill -0 "$pid" 2>/dev/null || { echo "$name exited during startup; see $log" >&2; wait "$pid" || :; exit 1; }
  sleep $((game_seconds-2))
  ticks=$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo unavailable)
  kill -TERM "$pid" 2>/dev/null || :; waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do sleep 1; waited=$((waited+1)); done
  kill -KILL "$pid" 2>/dev/null || :; wait "$pid" || :
  end=$(date +%s%N); elapsed=$(( (end-start)/1000000 )); hz=$(getconf CLK_TCK)
  case $ticks in *[!0-9]*|'') cpu_ms=unavailable;; *) cpu_ms=$((ticks*1000/hz));; esac
  echo "$name host_elapsed_ms=$elapsed process_cpu_ms=$cpu_ms log=$log"
  if [ -s "$trace" ]; then summarise_trace "$name all" "$trace" 0; summarise_trace "$name final_60s" "$trace" 60000; else echo "$name present_stats=unavailable"; fi
done
echo "Complete. Per-rate traces and logs are in $work."
