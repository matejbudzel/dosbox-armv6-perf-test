# DOSBox ARMv6 performance experiment

Reproducible Raspberry Pi 1 comparison of the installed distro DOSBox against two Debian-source `0.74-3-5` ARMv6 hard-float builds: portable normal core and the historical ARMV4LE dynrec backend. `scripts/build-armv6.sh` uses the real Pi sysroot/crt objects and the staged pi-286-games SDL 1.2 fbcon build.

The CPU-only Pi command is `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.1.1/run.sh | sh`. It uses SDL's dummy video driver, so no framebuffer is required. It runs one warm-up and five measured deterministic DOS COM workloads, records host wall-clock timings, and checks each guest checksum.

The graphics/audio and Grand Prix integration round is pinned separately: `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.2.1/run-integration.sh | sh`. Start it on the active `tty1` console. It benchmarks a deterministic mode-13h/PC-speaker COM workload, then runs `/home/dietpi/pi-286-game-files/grand-prix/GP.EXE` for a fixed 60-second integration soak per variant. The Grand Prix soak reports process CPU time and preserved logs; it is deliberately not presented as a speed ratio.

The offline sysroot proves Raspbian glibc `2.41-12+rpt1+deb13u3`; it does not contain dpkg status or the installed DOSBox binary version. We therefore pin Debian Trixie source `0.74-3-5`, matching current Trixie package metadata; the exact target binary revision remains for the Pi runner to print.
