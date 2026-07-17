#!/bin/bash

# WEB (WASM) LAME (libmp3lame) BUILD
# Autotools build via Emscripten. The lame mirror nests its source in a lame/
# subdirectory, so cd there first (like the other platforms). The nested tree
# ships a 2002-era configure, but the "configure missing" check below looks at
# ${BASEDIR}/src/lame/configure (which never exists), so autoreconf always runs
# and installs a wasm-aware config.sub. x86 assembly needs nasm and is skipped
# automatically for the wasm host. Static + PIC. lame installs no pkg-config
# file; one is generated manually below.

cd "${LIB_NAME}" || return 1

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_lame} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-maintainer-mode \
  --disable-frontend \
  --disable-efence \
  --disable-gtktest \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_libmp3lame_package_config "3.100" || return 1
