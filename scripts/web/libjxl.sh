#!/bin/bash

# WEB (WASM) LIBJXL BUILD
# CMake build via Emscripten with bundled brotli, highway and skcms (git
# submodules). highway supports wasm SIMD natively under -msimd128. libjxl is
# C++; runtime resolves at the main-module link, like x265. Sizeless vectors and
# the x86 AVX-512 targets are disabled like the other platforms. Static + PIC.

LIBJXL_SOURCE_DIR="${BASEDIR}/src/${LIB_NAME}"

cd "${LIBJXL_SOURCE_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
git submodule update --init third_party/brotli third_party/highway third_party/skcms 1>>"${BASEDIR}"/build.log 2>&1 || return 1

mkdir -p "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
cd "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emcmake cmake -Wno-dev \
  -DCMAKE_VERBOSE_MAKEFILE=0 \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${LIB_INSTALL_PREFIX}" \
  -DEMSCRIPTEN_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
  -DBUILD_SHARED_LIBS=0 \
  -DBUILD_TESTING=0 \
  -DHWY_ENABLE_CONTRIB=0 \
  -DHWY_ENABLE_EXAMPLES=0 \
  -DHWY_ENABLE_TESTS=0 \
  -DHWY_WARNINGS_ARE_ERRORS=0 \
  -DJPEGXL_BUNDLE_LIBPNG=0 \
  -DJPEGXL_ENABLE_TOOLS=0 \
  -DJPEGXL_ENABLE_DEVTOOLS=0 \
  -DJPEGXL_ENABLE_JPEGLI=0 \
  -DJPEGXL_ENABLE_JPEGLI_LIBJPEG=0 \
  -DJPEGXL_INSTALL_JPEGLI_LIBJPEG=0 \
  -DJPEGXL_ENABLE_DOXYGEN=0 \
  -DJPEGXL_ENABLE_MANPAGES=0 \
  -DJPEGXL_ENABLE_BENCHMARK=0 \
  -DJPEGXL_ENABLE_EXAMPLES=0 \
  -DJPEGXL_ENABLE_JNI=0 \
  -DJPEGXL_ENABLE_SJPEG=0 \
  -DJPEGXL_ENABLE_OPENEXR=0 \
  -DJPEGXL_ENABLE_SKCMS=1 \
  -DJPEGXL_ENABLE_VIEWERS=0 \
  -DJPEGXL_ENABLE_TCMALLOC=0 \
  -DJPEGXL_ENABLE_PLUGINS=0 \
  -DJPEGXL_ENABLE_FUZZERS=0 \
  -DJPEGXL_ENABLE_TRANSCODE_JPEG=0 \
  -DJPEGXL_ENABLE_AVX512=0 \
  -DJPEGXL_ENABLE_AVX512_SPR=0 \
  -DJPEGXL_ENABLE_AVX512_ZEN4=0 \
  -DJPEGXL_ENABLE_SIZELESS_VECTORS=0 \
  -DJPEGXL_FORCE_NEON=0 \
  -DJPEGXL_WARNINGS_AS_ERRORS=0 \
  "${LIBJXL_SOURCE_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILES (libjxl + bundled brotli)
cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/*.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
