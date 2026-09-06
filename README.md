# DOSBox ARMv6 performance experiment

Reproducible Raspberry Pi 1 comparison of the installed distro DOSBox against two Debian-source `0.74-3-5` ARMv6 hard-float builds: portable normal core and the historical ARMV4LE dynrec backend. `scripts/build-armv6.sh` uses the real Pi sysroot/crt objects and the staged pi-286-games SDL 1.2 fbcon build.

The CPU-only Pi command is `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.1.1/run.sh | sh`. It uses SDL's dummy video driver, so no framebuffer is required. It runs one warm-up and five measured deterministic DOS COM workloads, records host wall-clock timings, and checks each guest checksum.

The graphics/audio and Grand Prix integration round is pinned separately: `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.3.1/run-integration.sh | sh`. Start it on the active `tty1` console. It benchmarks a deterministic mode-13h/PC-speaker COM workload, then launches the authoritative `GPEGA.EXE` directly with `machine=ega`, 8 MB memory, Sound Blaster Pro emulation, and the pi-286-games baseline `cycles=fixed 3000`. By default it compares distro normal against custom dynrec only, then runs each Grand Prix variant for 180 seconds. The soak reports process CPU time, SDL present FPS, maximum frame gap, >33 ms gaps, and preserved logs; it is deliberately not presented as a speed ratio. Set `GP_CYCLES=max` only for a saturation soak or `INCLUDE_CUSTOM_NORMAL=1` to add the custom normal build.

For dynrec pacing tuning, the dedicated sweep runs only dynrec for three minutes each at fixed 2000, 2500, 3000, and 3500 cycles: `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.3.2/run-gp-dynrec-sweep.sh | sh`. It prints whole-run and final-60-second present cadence summaries per rate.

The offline sysroot proves Raspbian glibc `2.41-12+rpt1+deb13u3`; it does not contain dpkg status or the installed DOSBox binary version. We therefore pin Debian Trixie source `0.74-3-5`, matching current Trixie package metadata; the exact target binary revision remains for the Pi runner to print.
