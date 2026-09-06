#!/bin/sh
# Fetch exactly the Debian source package, including its quilt patch tarball.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${DOSBOX_SOURCE_CACHE:-$repo/.cache/debian-source}
version=0.74-3-5
base=https://deb.debian.org/debian/pool/main/d/dosbox
mkdir -p "$out"
fetch() { [ -f "$out/$1" ] || curl -fL -o "$out/$1" "$base/$1"; }
fetch "dosbox_${version}.dsc"
fetch dosbox_0.74-3.orig.tar.gz
fetch "dosbox_${version}.debian.tar.xz"
cd "$out"
printf '%s  %s\n' \
  c0d13dd7ed2ed363b68de615475781e891cd582e8162b5c3669137502222260a dosbox_0.74-3.orig.tar.gz \
  1e68255d9487114570e45d392d045773818c330cbc4ecbfda17de8a75d5e006a "dosbox_${version}.debian.tar.xz" | sha256sum -c -
rm -rf dosbox-0.74-3
dpkg-source -x "dosbox_${version}.dsc"
