#!/bin/bash

# WEB (WASM) LIBPNG BUILD
# Autotools build via Emscripten. Hardware (x86/arm) optimizations are disabled for
# wasm. libpng needs zlib, which is provided by Emscripten's zlib port (-sUSE_ZLIB=1)
# rather than a separately built library. Static + PIC.

# PROVIDE ZLIB VIA THE EMSCRIPTEN PORT
export CFLAGS="${CFLAGS} -sUSE_ZLIB=1"
export LDFLAGS="${LDFLAGS} -sUSE_ZLIB=1"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libpng} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-unversioned-libpng-pc \
  --disable-unversioned-libpng-config \
  --disable-hardware-optimizations \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILES
cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
