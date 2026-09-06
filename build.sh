#!/bin/sh
# One persistent entrypoint for the local ARMv6 release build.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$repo/.cache/logs"
log=$repo/.cache/logs/build-armv6.log
# Do not permit host-build settings from an interactive shell to leak into
# configure.  The C++ compiler is the cached frontend used by pi-286-games.
unset CC CXX CPP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LIBS
export CXX="$repo/../pi-286-games/.cache/cross-cxx/usr/bin/arm-linux-gnueabihf-g++-14"
export DOSBOX_SOURCE_DIR="$repo/.cache/source/dosbox-0.74-3"
export JOBS="${JOBS:-2}"
echo "[$(date -Iseconds)] starting ARMv6 build" | tee "$log"
exec "$repo/scripts/build-armv6.sh" >>"$log" 2>&1
