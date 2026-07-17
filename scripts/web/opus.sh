#!/bin/bash

# WEB (WASM) OPUS BUILD
# Autotools build via Emscripten. Assembly, run-time cpu detection and SIMD
# intrinsics are x86/arm only, so they are disabled for wasm (portable C, which
# emscripten may still auto-vectorize under -msimd128). Custom modes stay enabled
# to match the other platforms. Static + PIC.

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_opus} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --enable-custom-modes \
  --disable-shared \
  --disable-fast-install \
  --disable-maintainer-mode \
  --disable-asm \
  --disable-rtcd \
  --disable-intrinsics \
  --disable-doc \
  --disable-extra-programs \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp opus.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
