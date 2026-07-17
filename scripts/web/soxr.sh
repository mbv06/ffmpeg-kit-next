#!/bin/bash

# WEB (WASM) SOXR BUILD
# CMake build via Emscripten. OpenMP is not available under Emscripten, so it is
# disabled. The SIMD rate-converter variants (WITH_CR32S/CR64S) are disabled
# explicitly: Emscripten emulates enough of the SSE headers for soxr's detection
# to pass, but its x86 SIMD source does not compile to wasm. soxr installs no
# pkg-config file; one is generated manually below. Static + PIC.

mkdir -p "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
cd "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# soxr 0.1.3 declares cmake_minimum_required(3.1), which modern CMake refuses
emcmake cmake -Wno-dev \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_VERBOSE_MAKEFILE=0 \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${LIB_INSTALL_PREFIX}" \
  -DEMSCRIPTEN_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
  -DBUILD_TESTS=0 \
  -DWITH_DEV_TRACE=0 \
  -DWITH_LSR_BINDINGS=0 \
  -DWITH_OPENMP=0 \
  -DWITH_PFFFT=1 \
  -DWITH_CR32S=0 \
  -DWITH_CR64S=0 \
  -DBUILD_SHARED_LIBS=0 \
  "${BASEDIR}"/src/"${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_soxr_package_config "0.1.3" || return 1
