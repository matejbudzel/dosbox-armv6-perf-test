#!/bin/sh
# Cross-build both variants from the same patched Debian source tree.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sysroot=${PI286_SYSROOT:-$repo/../pi-286-games/.cache/pi286-sysroot}
sdl_stage=${SDL12_FBCON_STAGE_DIR:-$repo/../pi-286-games/.cache/sdl12-fbcon-stage}
source=${DOSBOX_SOURCE_DIR:-$repo/.cache/debian-source/dosbox-0.74-3}
work=${DOSBOX_BUILD_DIR:-$repo/.cache/build}
release=${DOSBOX_RELEASE_DIR:-$repo/release}
cc=${CROSS_COMPILE:-arm-linux-gnueabihf-}gcc
# The cached frontend is deliberately explicit: Debian's base cross package
# only provides C, while an inherited host CXX makes configure detect host SDL.
cxx=${CXX:-$repo/../pi-286-games/.cache/cross-cxx/usr/bin/arm-linux-gnueabihf-g++-14}
flags='-O2 -fomit-frame-pointer -marm -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard'
runtime="$sysroot/lib/arm-linux-gnueabihf"
sdl="$sdl_stage/opt/sdl12-fbcon"
for tool in "$cc" "$cxx" make file readelf strings dpkg-source; do command -v "$tool" >/dev/null 2>&1 || { echo "Missing $tool" >&2; exit 1; }; done
"$cc" -dumpmachine | grep -qx arm-linux-gnueabihf || { echo "C compiler is not arm-linux-gnueabihf: $cc" >&2; exit 1; }
"$cxx" -dumpmachine | grep -qx arm-linux-gnueabihf || { echo "C++ compiler is not arm-linux-gnueabihf: $cxx" >&2; exit 1; }
[ -f "$runtime/Scrt1.o" ] && [ -f "$runtime/crti.o" ] && [ -f "$runtime/crtn.o" ] || { echo "Pi ARMv6 crt objects missing from $sysroot" >&2; exit 1; }
[ -f "$sdl/lib/libSDL-1.2.so.0.11.5" ] || { echo "Staged Pi SDL fbcon library missing from $sdl" >&2; exit 1; }
[ -d "$source" ] || "$repo/scripts/fetch-debian-source.sh"
"$repo/benchmark/build-com.sh" "$release/guest/CPUBENCH.COM"
if [ "${CLEAN:-0}" = 1 ]; then rm -rf "$work"; fi
rm -rf "$release/bin" "$release/lib" "$release/config"
mkdir -p "$work" "$release/bin" "$release/lib" "$release/config"
build_one() {
  name=$1; dynamic=$2; dir="$work/$name"
  if [ ! -d "$dir" ]; then cp -a "$source" "$dir"; fi
  cd "$dir"
  # Debian's extracted patch timestamps otherwise trigger an unnecessary
  # autoreconf with the historical automake-1.15 tool.
  find . \( -name aclocal.m4 -o -name configure -o -name Makefile.in \) -exec touch {} +
  if [ ! -f config.status ]; then CC="$cc --sysroot=$sysroot" CXX="$cxx -B$repo/tools --sysroot=$sysroot" \
  CFLAGS="--sysroot=$sysroot $flags" CXXFLAGS="--sysroot=$sysroot $flags" \
  CPPFLAGS="--sysroot=$sysroot -I$sdl/include/SDL" \
  # The cached g++ frontend was extracted without its optional LTO plugin.
  # DOSBox is not built with LTO, so suppress its distro default at link time.
  LDFLAGS="--sysroot=$sysroot $flags -fno-use-linker-plugin -L$sdl/lib -Wl,-rpath,\$ORIGIN/../lib" \
  # The staged sdl-config has its target prefix (/opt/sdl12-fbcon) compiled
  # in. Override it for configure-time host-side header/link checks.
  SDL_CONFIG="$sdl/bin/sdl-config --prefix=$sdl --exec-prefix=$sdl" \
  ./configure --build="$(gcc -dumpmachine)" --host=arm-linux-gnueabihf --disable-sdltest --disable-alsatest --disable-opengl --disable-debug ${dynamic}; fi
  if [ "$name" = dynrec ]; then
    # 0.74-3 has ARMV4LE but configure does not select ARM automatically.
    sed -i 's/^#define C_TARGETCPU UNKNOWN$/#define C_TARGETCPU ARMV4LE/; s@^/\* #undef C_DYNREC \*/$@#define C_DYNREC 1@' config.h
    grep -qx '#define C_TARGETCPU ARMV4LE' config.h
    grep -qx '#define C_DYNREC 1' config.h
  fi
  # Make's final executable link uses CXX directly and can discard configure's
  # LDFLAGS; inject the no-LTO-plugin option at that exact invocation.
  make -k CXX="$cxx -B$repo/tools --sysroot=$sysroot -fno-use-linker-plugin $flags" -j"${JOBS:-$(getconf _NPROCESSORS_ONLN)}" || :
  # Debian cross GCC's crt objects are ARMv7. Relink every DOSBox object with
  # the ARMv6 crt/runtime copied from the real Pi sysroot, never the toolchain
  # defaults.  Static archives preserve the same link order as src/Makefile.
  gcc_runtime="$sysroot/usr/lib/gcc/arm-linux-gnueabihf/14"
  "$cxx" -B"$repo/tools" --sysroot="$sysroot" $flags -fno-use-linker-plugin -pie -nostartfiles -nodefaultlibs \
    "$runtime/Scrt1.o" "$runtime/crti.o" "$gcc_runtime/crtbeginS.o" src/dosbox.o \
    src/cpu/libcpu.a src/debug/libdebug.a src/dos/libdos.a src/fpu/libfpu.a \
    src/hardware/libhardware.a src/gui/libgui.a src/ints/libints.a src/misc/libmisc.a \
    src/shell/libshell.a src/hardware/mame/libmame.a src/hardware/serialport/libserial.a src/libs/gui_tk/libgui_tk.a \
    -L"$sdl/lib" -Wl,-rpath,'$ORIGIN/../lib' -lSDL -lasound -lm -ldl -lpthread \
    "$runtime/libstdc++.so.6" "$runtime/libgcc_s.so.1" "$runtime/libc.so.6" \
    "$gcc_runtime/crtendS.o" "$runtime/crtn.o" -o src/dosbox-armv6
  cp src/dosbox-armv6 "$release/bin/dosbox-$name"
  cp config.h "$release/config/config-$name.h"
}
build_one normal '--disable-dynamic-core'
build_one dynrec ''
cp "$sdl/lib/libSDL-1.2.so.0.11.5" "$release/lib/"
ln -s libSDL-1.2.so.0.11.5 "$release/lib/libSDL-1.2.so.0"
for f in "$release/bin/dosbox-normal" "$release/bin/dosbox-dynrec"; do
  file "$f" | grep -q 'ARM'
  readelf -A "$f" | grep -Eq 'Tag_CPU_arch: v6|Tag_CPU_arch: v6KZ'
  readelf -A "$f" | grep -q 'Tag_ABI_VFP_args: VFP registers'
done
cp "$repo/configs/cpu-normal.conf.in" "$repo/configs/cpu-dynamic.conf.in" "$release/config/"
printf 'Built ARMv6 hard-float binaries in %s\n' "$release"
