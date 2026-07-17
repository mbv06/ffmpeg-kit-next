#!/bin/bash

# WEB (WASM) LIBTHEORA BUILD
# Autotools build via Emscripten. Assembly is x86/arm only, so it is disabled for
# wasm (portable C). Depends on libogg and libvorbis (built earlier in the loop),
# located via explicit --with paths. Static + PIC. theora regenerates its build
# system with autogen.sh rather than plain autoreconf (same as the other platforms).

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libtheora} -eq 1 ]]; then

  # WORKAROUND NOT TO RUN CONFIGURE AT THE END OF autogen.sh
  ${SED_INLINE} 's/$srcdir\/configure/#$srcdir\/configure/g' "${BASEDIR}"/src/"${LIB_NAME}"/autogen.sh 1>>"${BASEDIR}"/build.log 2>&1 || return 1

  ./autogen.sh 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-ogg-includes="${LIB_INSTALL_BASE}"/libogg/include \
  --with-ogg-libraries="${LIB_INSTALL_BASE}"/libogg/lib \
  --with-vorbis-includes="${LIB_INSTALL_BASE}"/libvorbis/include \
  --with-vorbis-libraries="${LIB_INSTALL_BASE}"/libvorbis/lib \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-asm \
  --disable-examples \
  --disable-telemetry \
  --disable-sdltest \
  --disable-valgrind-testing \
  --disable-spec \
  --disable-oggtest \
  --disable-vorbistest \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILES
cp theora.pc theoradec.pc theoraenc.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
