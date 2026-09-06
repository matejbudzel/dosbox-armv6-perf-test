#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${1:-$repo/release/guest/CPU-BENCH.COM}
mkdir -p "$(dirname "$out")" "$repo/.cache"
case $(basename "$out") in
  CPU-BENCH.COM|CPUBENCH.COM) source=cpu-bench.S; object=cpu-bench.o;;
  AV-BENCH.COM) source=av-bench.S; object=av-bench.o;;
  *) echo "Unknown benchmark output: $out" >&2; exit 2;;
esac
as --32 "$repo/benchmark/$source" -o "$repo/.cache/$object"
ld -m elf_i386 -Ttext 0x100 --oformat binary "$repo/.cache/$object" -o "$out"
rm -f "$repo/.cache/$object"
