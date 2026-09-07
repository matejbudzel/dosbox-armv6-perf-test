# DOSBox ARMv6 performance experiment

Reproducible Raspberry Pi 1 comparison of the installed distro DOSBox against two Debian-source `0.74-3-5` ARMv6 hard-float builds: portable normal core and the historical ARMV4LE dynrec backend. `scripts/build-armv6.sh` uses the real Pi sysroot/crt objects and the staged pi-286-games SDL 1.2 fbcon build.

The CPU-only Pi command is `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.1.1/run.sh | sh`. It uses SDL's dummy video driver, so no framebuffer is required. It runs one warm-up and five measured deterministic DOS COM workloads, records host wall-clock timings, and checks each guest checksum.

The graphics/audio and Grand Prix integration round is pinned separately: `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.3.1/run-integration.sh | sh`. Start it on the active `tty1` console. It benchmarks a deterministic mode-13h/PC-speaker COM workload, then launches the authoritative `GPEGA.EXE` directly with `machine=ega`, 8 MB memory, Sound Blaster Pro emulation, and the pi-286-games baseline `cycles=fixed 3000`. By default it compares distro normal against custom dynrec only, then runs each Grand Prix variant for 180 seconds. The soak reports process CPU time, SDL present FPS, maximum frame gap, >33 ms gaps, and preserved logs; it is deliberately not presented as a speed ratio. Set `GP_CYCLES=max` only for a saturation soak or `INCLUDE_CUSTOM_NORMAL=1` to add the custom normal build.

For dynrec pacing tuning, the dedicated sweep runs only dynrec for three minutes each at fixed 2000, 2500, 3000, and 3500 cycles: `curl -fsSL https://raw.githubusercontent.com/matejbudzel/dosbox-armv6-perf-test/v0.3.2/run-gp-dynrec-sweep.sh | sh`. It prints whole-run and final-60-second present cadence summaries per rate.

The offline sysroot proves Raspbian glibc `2.41-12+rpt1+deb13u3`; it does not contain dpkg status or the installed DOSBox binary version. We therefore pin Debian Trixie source `0.74-3-5`, matching current Trixie package metadata.

## Results and conclusion (Raspberry Pi Model B Rev 1)

The target was subsequently identified as Raspbian GNU/Linux 13 (Trixie), running on a 900 MHz ARM1176JZF-S (`armv6l`, VFP hard-float), with the `performance` governor. Its installed DOSBox is Debian/Raspbian `0.74-3-5+b1`. `readelf -A` confirms that the distro binary is an ARMv6 VFP hard-float binary and not an ARMv7 build.

The custom binaries were built from the corresponding Debian source package, `dosbox 0.74-3-5`, with the real Pi CRT/runtime objects and these target flags:

```
-marm -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard
```

The dynrec build enables `C_DYNREC=1`, `C_TARGETCPU=ARMV4LE`, and DOSBox's historical default `risc_armv4le-thumb-niw` emitter. All reported deterministic guest checksums matched the expected values.

| Workload | Distro normal | Custom normal | Custom ARM dynrec | Result |
| --- | ---: | ---: | ---: | --- |
| CPU COM, median wall time | 10.469 s | 17.178 s | 4.742 s | Dynrec was 2.21x the distro speed and 3.62x custom-normal speed. |
| Mode-13h VGA + PC-speaker COM, median wall time | 4.710 s | — | 3.348 s | Dynrec was 1.41x the distro speed. |

These figures establish that the ARM dynrec backend is real, correct for this workload, and substantially improves raw CPU emulation. They do **not** establish that it produces the best interactive game experience.

### Grand Prix: the important limitation

The integration test launches `GPEGA.EXE` directly in the same EGA/8 MB configuration used by pi-286-games, with Sound Blaster Pro emulation. It must run from `tty1` because the real SDL 1.2 fbcon path needs `/dev/fb0`; it is not an SSH/headless benchmark.

In the three-minute dynrec sweep, lower fixed cycle budgets had materially better SDL presentation cadence than the pi-286-games baseline of `fixed 3000`:

| Dynrec fixed cycles | Whole-run present rate | Final active-minute present rate | Notable active-phase stall |
| ---: | ---: | ---: | --- |
| 2000 | 23.21/s | 23.98/s | no multi-second final-minute stall observed |
| 2500 | 19.54/s | 19.52/s | no multi-second final-minute stall observed |
| 3000 | 16.66/s | 14.54/s | up to 1.37 s |
| 3500 | 14.67/s | 14.15/s | up to 3.75 s |

The whole-run maximum gap includes menus/loading, so the final active-minute data is the useful comparison. A `>33 ms` gap count is also not an FPS measure: Grand Prix itself commonly presents around 15–25 times per second. The SDL interposer measures DOSBox's calls to SDL present, not physical HDMI refresh or vblank.

Subjectively, the distro normal-core DOSBox remained a little smoother and less distracting in Grand Prix than dynrec at the tested baseline, despite dynrec winning the synthetic workloads. The evidence points to fixed-cycle pacing and game integration, rather than lack of raw dynrec throughput, as the limiting factor. `fixed 2000` is the strongest next candidate for direct dynrec play, with `fixed 2500` a reasonable compromise; neither has yet been established as preferable to the distro build in extended hands-on play.

### Practical recommendation

This experiment does not justify replacing the existing streaming setup solely on the basis of the synthetic speedup. Direct DOSBox is demonstrably viable for CPU-heavy and simple VGA/audio workloads, but Grand Prix—the representative intended game—needs better subjective pacing than the tested dynrec configuration currently provides. Keep the streaming path as the dependable default for now; use the direct distro DOSBox or experimental dynrec configuration for further game-specific evaluation.

There is no obvious remaining low-risk compiler flag expected to change that conclusion. The build already has the appropriate ARMv6/ARM1176/VFP hard-float options. A separate, clearly experimental build using DOSBox's alternative `risc_armv4le-s3.h` backend (labelled "speed-tweaked ARM" in the source) is the one plausible source-level experiment. It must remain separate from the validated `thumb-niw` artifact and be checked with the deterministic workloads and the same Grand Prix cadence/subjective tests before drawing conclusions.
