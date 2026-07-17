#!/bin/bash

# WEB (WASM) LIBWEBP BUILD
#
# Built via CMake (not autotools) so the command-line tools (cwebp/dwebp/…), which
# are pointless under Emscripten, are disabled and only the libraries FFmpeg links
# are produced. Static (linked into FFmpeg's side modules); run-web.sh's CFLAGS
# already carry -fPIC. SIMD is disabled for a portable first build. run-web.sh has
# exported CFLAGS/CXXFLAGS/LDFLAGS and pre-cleaned ${BUILD_DIR}.

mkdir -p "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
cd "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emcmake cmake "${BASEDIR}/src/${LIB_NAME}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${LIB_INSTALL_PREFIX}" \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DWEBP_ENABLE_SIMD=OFF \
  -DWEBP_BUILD_LIBWEBPMUX=ON \
  -DWEBP_BUILD_CWEBP=OFF \
  -DWEBP_BUILD_DWEBP=OFF \
  -DWEBP_BUILD_GIF2WEBP=OFF \
  -DWEBP_BUILD_IMG2WEBP=OFF \
  -DWEBP_BUILD_VWEBP=OFF \
  -DWEBP_BUILD_WEBPINFO=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF \
  -DWEBP_BUILD_EXTRAS=OFF \
  -DWEBP_BUILD_ANIM_UTILS=OFF 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# COPY THE GENERATED PKG-CONFIG FILES INTO THE SHARED PKG-CONFIG DIRECTORY
cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/*.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
