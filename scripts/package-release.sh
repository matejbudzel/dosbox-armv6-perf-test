#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
release=$repo/release; version=${1:-v0.1.0}; mkdir -p "$release/scripts" "$repo/dist"
cp "$repo/scripts/run-on-pi.sh" "$release/scripts/"; chmod +x "$release/scripts/run-on-pi.sh"
cat > "$release/BUILD-MANIFEST.txt" <<EOF
release=$version
source_package=dosbox 0.74-3-5 (Debian Trixie), source https://deb.debian.org/debian/pool/main/d/dosbox/
orig_sha256=c0d13dd7ed2ed363b68de615475781e891cd582e8162b5c3669137502222260a
debian_tar_sha256=1e68255d9487114570e45d392d045773818c330cbc4ecbfda17de8a75d5e006a
target=ARM1176JZF-S ARMv6zk armhf VFP hard-float
flags=-marm -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard
dynrec=C_DYNREC=1 C_TARGETCPU=ARMV4LE risc_armv4le-thumb-niw
EOF
tar -C "$release" -czf "$repo/dist/dosbox-armv6-perf-test-$version.tar.gz" .
(cd "$repo/dist" && sha256sum "dosbox-armv6-perf-test-$version.tar.gz" > SHA256SUMS)
