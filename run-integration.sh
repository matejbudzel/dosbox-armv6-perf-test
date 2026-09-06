#!/bin/sh
# Pinned bootstrap for the graphics/audio and Grand Prix integration round.
set -eu
release=v0.2.1
base=https://github.com/matejbudzel/dosbox-armv6-perf-test/releases/download/$release
work=${DOSBOX_ARMV6_PERF_WORKDIR:-/tmp/dosbox-armv6-perf-integration}
archive=dosbox-armv6-perf-test-v0.2.1.tar.gz
mkdir -p "$work"; cd "$work"
curl -fL -o SHA256SUMS "$base/SHA256SUMS"
curl -fL -o "$archive" "$base/$archive"
grep "  $archive$" SHA256SUMS | sha256sum -c -
rm -rf payload; mkdir payload; tar -xzf "$archive" -C payload
exec sh payload/scripts/run-integration-on-pi.sh "$@"
