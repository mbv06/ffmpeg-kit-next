#!/bin/bash

# WEB (WASM) XVIDCORE BUILD (GPL)
# Autotools build via Emscripten. The source nests the build system under
# xvidcore/build/generic. Assembly is x86/arm only, so it is disabled for wasm.
# Requires FFmpeg's --enable-gpl to actually be linked. Static + PIC.

cd "${BASEDIR}"/src/"${LIB_NAME}"/"${LIB_NAME}"/build/generic || return 1

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/"${LIB_NAME}"/build/generic/configure ]] || [[ ${RECONF_xvidcore} -eq 1 ]]; then
  ./bootstrap.sh 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --disable-assembly \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_xvidcore_package_config "1.3.7" || return 1

# WORKAROUND TO REMOVE DYNAMIC LIBS SO FFMPEG LINKS THE STATIC ARCHIVE
rm -f "${LIB_INSTALL_PREFIX}"/lib/libxvidcore.so* 1>>"${BASEDIR}"/build.log 2>&1
