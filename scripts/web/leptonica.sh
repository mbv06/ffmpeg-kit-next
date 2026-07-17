#!/bin/bash

# WEB (WASM) LEPTONICA BUILD
# Autotools build via Emscripten. Only pulled in as a tesseract dependency (FFmpeg
# has no direct leptonica integration). zlib comes from Emscripten's zlib port;
# the image codecs (png, jpeg, tiff, webp, giflib) were built earlier in the loop
# and are located via pkg-config / explicit paths. Static + PIC.

# UPDATE BUILD FLAGS
export CFLAGS="${CFLAGS} -sUSE_ZLIB=1 -I${LIB_INSTALL_BASE}/giflib/include"
export CXXFLAGS="${CXXFLAGS} -sUSE_ZLIB=1"
export LDFLAGS="${LDFLAGS} -sUSE_ZLIB=1 -L${LIB_INSTALL_BASE}/giflib/lib"
# giflib has no .pc; its header path must be in CPPFLAGS too, because leptonica's
# giflib version check is an AC_PREPROC_IFELSE that uses the preprocessor (CPPFLAGS),
# not CFLAGS
export CPPFLAGS="-I${LIB_INSTALL_BASE}/giflib/include"

export LIBPNG_CFLAGS="$(pkg-config --cflags libpng 2>>"${BASEDIR}"/build.log)"
export LIBPNG_LIBS="$(pkg-config --libs-only-L libpng 2>>"${BASEDIR}"/build.log)"
export LIBWEBP_CFLAGS="$(pkg-config --cflags libwebp 2>>"${BASEDIR}"/build.log)"
export LIBWEBP_LIBS="$(pkg-config --libs-only-L libwebp 2>>"${BASEDIR}"/build.log)"
export LIBTIFF_CFLAGS="$(pkg-config --cflags libtiff-4 2>>"${BASEDIR}"/build.log)"
export LIBTIFF_LIBS="$(pkg-config --libs-only-L libtiff-4 2>>"${BASEDIR}"/build.log)"
export JPEG_CFLAGS="$(pkg-config --cflags libjpeg 2>>"${BASEDIR}"/build.log)"
export JPEG_LIBS="$(pkg-config --libs-only-L libjpeg 2>>"${BASEDIR}"/build.log)"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_leptonica} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-zlib \
  --with-libpng \
  --with-jpeg \
  --with-giflib \
  --with-libtiff \
  --with-libwebp \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-programs \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp lept.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
