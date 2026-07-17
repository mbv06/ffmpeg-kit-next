#!/bin/bash

# WEB (WASM) TWOLAME BUILD
# Autotools build via Emscripten. Portable C MP2 encoder with libsndfile support
# wired the same way as the native cross builds. Static + PIC.

# UPDATE BUILD FLAGS
export SNDFILE_CFLAGS="$(pkg-config --cflags sndfile 2>>"${BASEDIR}"/build.log)"
export SNDFILE_LIBS="$(pkg-config --libs --static sndfile 2>>"${BASEDIR}"/build.log)"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
# twolame's autogen.sh hardcodes a Darwin "glibtoolize" search (Homebrew-ism); the
# nix shell only ships libtoolize, so run autoreconf directly instead — it finds
# libtoolize and regenerates the same build files.
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_twolame} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# WORKAROUND TO DISABLE BUILDING OF DOCBOOK - BUILD SCRIPTS DO NOT GENERATE A TARGET FOR IT
${SED_INLINE} 's/dist_man_MANS = .*/dist_man_MANS =/g' "${BASEDIR}"/src/"${LIB_NAME}"/doc/Makefile 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
