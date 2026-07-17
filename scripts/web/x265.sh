#!/bin/bash

# WEB (WASM) X265 BUILD (GPL)
#
# x265 is a C++/CMake build. emcmake supplies the Emscripten toolchain file, which
# advertises CMAKE_SYSTEM_PROCESSOR=x86 by default; that would turn on x265's
# X265_ARCH_X86 paths (inline cpuid assembly that cannot compile to wasm).
# EMSCRIPTEN_SYSTEM_PROCESSOR is the toolchain's documented override; wasm32 makes
# x265 take its portable-C path with all assembly disabled. Static + PIC; CLI
# disabled. HIGH_BIT_DEPTH matches the Android/Apple builds. Requires FFmpeg's
# --enable-gpl to actually be linked.

# X265 HAS NO SINGLE-THREADED MODE; ITS THREAD POOL NEEDS REAL EMSCRIPTEN PTHREADS
if [[ ${FFMPEG_KIT_WEB_PTHREADS:-1} != "1" ]]; then
  echo -e "ERROR: x265 requires threads. Web x265 builds are only supported with Emscripten pthreads enabled\n" 1>>"${BASEDIR}"/build.log 2>&1
  return 1
fi

git checkout "${BASEDIR}"/src/"${LIB_NAME}"/source/CMakeLists.txt 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# WORKAROUND TO FIX static_assert ERRORS (same as the Android build); x265 defaults
# to -std=gnu++98, which is appended after CMAKE_CXX_FLAGS and rejects static_assert
${SED_INLINE} 's/gnu++98/c++11/g' "${BASEDIR}"/src/"${LIB_NAME}"/source/CMakeLists.txt 1>>"${BASEDIR}"/build.log 2>&1 || return 1

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
  -DENABLE_PIC=1 \
  -DENABLE_CLI=0 \
  -DHIGH_BIT_DEPTH=1 \
  -DENABLE_ASSEMBLY=0 \
  -DENABLE_SHARED=0 "${BASEDIR}"/src/"${LIB_NAME}"/source 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# Libs.private is generated from CMake's implicit C++ link libraries, which are
# host-toolchain noise under Emscripten (emcc resolves its own C++ runtime at the
# main-module link, and ignores -lm/-lpthread style flags). Keep only -lm so
# FFmpeg's static pkg-config queries stay deterministic.
${SED_INLINE} 's|^Libs.private:.*|Libs.private: -lm|' x265.pc 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp x265.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
