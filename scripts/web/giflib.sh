#!/bin/bash

# WEB (WASM) GIFLIB BUILD
# giflib ships a plain Makefile; ffmpeg-kit patches it into an autotools project
# (tools/patch/make/giflib) and generates the pkg-config file. Built static + PIC
# via the Emscripten toolchain.

# ADD S_IREAD/S_IWRITE ALIASES EXPECTED BY GIFLIB
export CFLAGS="$(get_cflags "${LIB_NAME}") -DS_IREAD=S_IRUSR -DS_IWRITE=S_IWUSR"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# APPLY THE AUTOTOOLS BUILD PATCH
cp "${BASEDIR}"/tools/patch/make/giflib/* "${BASEDIR}"/src/"${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# ALWAYS REGENERATE THE BUILD FILES WITH THE LOCAL AUTOTOOLS.
# giflib's shipped/previous autotools files bake in an automake version (aclocal-1.16)
# that is not present in this environment. Regenerating unconditionally produces build
# files that match the local automake and are newer than configure.ac, so make never
# re-runs aclocal during the build.
autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# GENERATE THE PKG-CONFIG FILE (giflib does not ship one)
create_giflib_package_config "5.2.2" || return 1
