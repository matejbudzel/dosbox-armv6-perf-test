# DOSBox ARMv6 performance experiment

Reproducible Raspberry Pi 1 comparison of the installed distro DOSBox against two Debian-source `0.74-3-5` ARMv6 hard-float builds: portable normal core and the historical ARMV4LE dynrec backend. `scripts/build-armv6.sh` uses the real Pi sysroot/crt objects and the staged pi-286-games SDL 1.2 fbcon build.

The eventual Pi command is `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.1.0/run.sh | sh`. The CPU benchmark uses SDL's dummy video driver, so no framebuffer is required. It runs one warm-up and five measured deterministic DOS COM workloads, records host wall-clock timings, and checks each guest checksum.

The offline sysroot proves Raspbian glibc `2.41-12+rpt1+deb13u3`; it does not contain dpkg status or the installed DOSBox binary version. We therefore pin Debian Trixie source `0.74-3-5`, matching current Trixie package metadata; the exact target binary revision remains for the Pi runner to print.
