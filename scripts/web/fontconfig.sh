#!/bin/bash

# WEB (WASM) FONTCONFIG BUILD
# Autotools build via Emscripten. Depends on expat and freetype (built earlier in
# the loop). iconv comes from Emscripten's musl libc; fontconfig 2.18 needs no
# uuid. --disable-cache-build is required: cross builds cannot run the cache
# generation tools. Static + PIC.

# WORKAROUND FOR va_copy DETECTION, WHICH NEEDS TO RUN A TEST PROGRAM WHEN CROSS-COMPILING
export ac_cv_va_copy=C99

# UPDATE BUILD FLAGS
export FREETYPE_CFLAGS="$(pkg-config --cflags freetype2 2>>"${BASEDIR}"/build.log)"
export FREETYPE_LIBS="$(pkg-config --libs --static freetype2 2>>"${BASEDIR}"/build.log)"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_fontconfig} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-expat="${LIB_INSTALL_BASE}"/expat \
  --without-libintl-prefix \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-cache-build \
  --disable-rpath \
  --disable-libxml2 \
  --disable-docs \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_fontconfig_package_config "2.18.1" || return 1
