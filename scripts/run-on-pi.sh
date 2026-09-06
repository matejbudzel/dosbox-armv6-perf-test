#!/bin/sh
# Runtime is isolated under /tmp and never changes the Pi.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runs=${RUNS:-5}; work=${DOSBOX_ARMV6_PERF_WORKDIR:-/tmp/dosbox-armv6-perf-test}
[ "$runs" -ge 3 ] 2>/dev/null || { echo 'RUNS must be >= 3' >&2; exit 2; }
date +%s%N >/dev/null 2>&1 || { echo 'GNU date with nanoseconds is required' >&2; exit 2; }
[ -x /usr/bin/dosbox ] || { echo '/usr/bin/dosbox is not installed' >&2; exit 2; }
[ -x "$root/bin/dosbox-normal" ] && [ -x "$root/bin/dosbox-dynrec" ] || { echo 'release is incomplete' >&2; exit 2; }
mkdir -p "$work/logs"; guest="$work/guest"; rm -rf "$guest"; cp -R "$root/guest" "$guest"
echo 'DOSBox ARMv6 performance experiment'; echo "work directory: $work"; echo "uname: $(uname -a)"
[ -r /etc/os-release ] && { echo 'os-release:'; sed -n '1,20p' /etc/os-release; }
[ -r /proc/cpuinfo ] && { echo 'cpuinfo:'; sed -n '1,100p' /proc/cpuinfo; }
for f in /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq; do [ -r "$f" ] && echo "$(basename "$f"): $(cat "$f")"; done
echo "distro DOSBox: $(/usr/bin/dosbox --version 2>&1 | head -1)"; echo 'custom build provenance:'; sed -n '1,160p' "$root/BUILD-MANIFEST.txt"
run_variant() {
    name=$1 binary=$2 template=$3; timings="$work/$name.times"; : > "$timings"; echo "== $name =="; run=0
    while [ "$run" -le "$runs" ]; do
        rm -f "$guest/RESULT.TXT"; sed "s|@GUESTDIR@|$guest|g" "$template" > "$work/$name.conf"
        start=$(date +%s%N)
        SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$binary" -conf "$work/$name.conf" >"$work/logs/$name-$run.log" 2>&1
        end=$(date +%s%N); result=$(sed -n 's/^PI286_CPU_BENCH_RESULT=//p' "$guest/RESULT.TXT" 2>/dev/null | tr -d '\r' | tail -1)
        [ "$result" = 79B10000 ] || { echo "$name guest checksum '$result' is not expected 79B10000; see $work/logs/$name-$run.log" >&2; exit 1; }
        [ "$run" -gt 0 ] && printf '%s %s\n' "$(( (end-start)/1000000 ))" "$result" | tee -a "$timings"
        run=$((run+1))
    done
}
run_variant distro /usr/bin/dosbox "$root/config/cpu-normal.conf.in"
run_variant custom-normal "$root/bin/dosbox-normal" "$root/config/cpu-normal.conf.in"
# A dynamic request on a binary without C_DYNREC fails rather than becoming a normal result.
run_variant custom-dynrec "$root/bin/dosbox-dynrec" "$root/config/cpu-dynamic.conf.in"
summarise() {
    name=$1; file="$work/$name.times"; checks=$(awk '{print $2}' "$file" | sort -u | tr '\n' ' ')
    [ "$(awk '{print $2}' "$file" | sort -u | wc -l | tr -d ' ')" = 1 ] || { echo "$name checksum changed: $checks" >&2; exit 1; }
    set -- $(awk '{print $1}' "$file" | sort -n); count=$#; middle=$(( (count+1)/2 )); eval "median=\${$middle}"; max=$(awk '{print $1}' "$file" | sort -n | tail -1)
    echo "$name: timings_ms=[$*] min=$1 median=$median max=$max checksum=$checks"
    case $name in distro) distro_median=$median;; custom-normal) normal_median=$median;; custom-dynrec) dynrec_median=$median;; esac
}
echo '== summary: host wall-clock milliseconds =='; summarise distro; summarise custom-normal; summarise custom-dynrec
awk -v d="$distro_median" -v n="$normal_median" -v y="$dynrec_median" 'BEGIN { printf "custom-normal vs distro: %.3fx\ncustom-dynrec vs distro: %.3fx\ncustom-dynrec vs custom-normal: %.3fx\n",d/n,d/y,n/y }'
