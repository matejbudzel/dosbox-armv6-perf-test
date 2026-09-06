#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${1:-$repo/release/guest/CPU-BENCH.COM}
mkdir -p "$(dirname "$out")" "$repo/.cache"
as --32 "$repo/benchmark/cpu-bench.S" -o "$repo/.cache/cpu-bench.o"
ld -m elf_i386 -Ttext 0x100 --oformat binary "$repo/.cache/cpu-bench.o" -o "$out"
rm -f "$repo/.cache/cpu-bench.o"
