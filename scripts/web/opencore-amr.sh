#!/bin/bash

# WEB (WASM) OPENCORE-AMR BUILD
# Autotools build via Emscripten. opencore-amr compiles its .cpp sources in C mode
# (its default "compile as C", which adds -x c -std=c99) because the code uses the
# C-only `register` storage class that C++17 rejects. That -x c collides with the
# -std=c++17 our CXXFLAGS inject, so strip it here; opencore supplies its own
# -std=c99. Runtime resolves at the main-module link. Static + PIC.

# STRIP -std=c++17: opencore-amr compiles as C (-x c) and clang rejects a C++ std there
export CXXFLAGS="${CXXFLAGS//-std=c++17/}"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_opencore_amr} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-maintainer-mode \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp amrnb/*.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
