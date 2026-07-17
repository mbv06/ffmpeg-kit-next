#!/bin/bash

# WEB (WASM) TESSERACT BUILD
# Autotools build via Emscripten. tesseract is C++; runtime resolves at the
# main-module link, like x265. leptonica and the image codecs were built earlier
# in the loop and located via pkg-config. tesseract gates its SIMD on host_cpu,
# and the wasm32 host matches none of its x86/arm cases, so the portable-C++ path
# is taken automatically. Static + PIC.

# UPDATE BUILD FLAGS
export LEPTONICA_CFLAGS=" $(pkg-config --cflags lept 2>>"${BASEDIR}"/build.log)"
export LEPTONICA_LIBS=" $(pkg-config --libs-only-L lept 2>>"${BASEDIR}"/build.log)"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_tesseract} -eq 1 ]]; then
  ./autogen.sh 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

# WORKAROUND TO MANUALLY SET ENDIANNESS (cross builds cannot run the test program)
export ac_cv_c_bigendian=no

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --without-tensorflow \
  --without-curl \
  --without-archive \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-debug \
  --disable-graphics \
  --disable-openmp \
  --disable-tessdata-prefix \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# bin_PROGRAMS= skips the tesseract CLI binary: it links as a standalone wasm
# executable needing all of leptonica + the image codecs + the zlib port resolved,
# which is fragile and unnecessary. FFmpeg only consumes libtesseract; its own
# configure adds the full Requires chain (lept, image codecs) to the side-module
# link, so the library's deferred leptonica symbols resolve there.
emmake make -j$(get_cpu_count) bin_PROGRAMS= 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install bin_PROGRAMS= 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_tesseract_package_config "5.4.1" || return 1
