#!/bin/sh
# Pinned bootstrap for the dynrec-only Grand Prix fixed-cycle sweep.
set -eu
release=v0.3.2
base=https://github.com/matejbudzel/dosbox-armv6-perf-test/releases/download/$release
work=${DOSBOX_ARMV6_PERF_WORKDIR:-/tmp/dosbox-armv6-gp-dynrec-sweep}
archive=dosbox-armv6-perf-test-v0.3.2.tar.gz
mkdir -p "$work"; cd "$work"
curl -fL -o SHA256SUMS "$base/SHA256SUMS"
curl -fL -o "$archive" "$base/$archive"
grep "  $archive$" SHA256SUMS | sha256sum -c -
rm -rf payload; mkdir payload; tar -xzf "$archive" -C payload
exec sh payload/scripts/run-gp-dynrec-sweep-on-pi.sh "$@"
