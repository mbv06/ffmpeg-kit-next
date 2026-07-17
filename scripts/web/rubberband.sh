#!/bin/bash

# WEB (WASM) RUBBERBAND BUILD (GPL)
# Meson build via a generated Emscripten cross file (meson ignores the
# CFLAGS/CXXFLAGS environment in cross builds). rubberband is C++; runtime
# resolves at the main-module link, like x265/harfbuzz. The builtin FFT and
# libsamplerate resampler mirror the Android build while keeping the command-line
# tools disabled. Requires FFmpeg's --enable-gpl to actually be linked. Static + PIC.

# rubberband 4.0.0 uses bare size_t in src/common/mathmisc.cpp without including
# <cstddef>; newer libc++ no longer pulls it in transitively via <cmath>, and its
# <cstddef> only defines std::size_t. Force-include the C header, which defines
# global ::size_t. Prepended to CXXFLAGS so it lands in the cross file below.
export CXXFLAGS="-include stddef.h ${CXXFLAGS}"

# SET BUILD FLAGS
CROSS_FILE="${BASEDIR}"/src/"${LIB_NAME}"/package/crossfiles/$ARCH-$FFMPEG_KIT_BUILD_TYPE.meson

mkdir -p "$(dirname "$CROSS_FILE")" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
create_mason_cross_file "$CROSS_FILE" || return 1

# ALWAYS CLEAN THE PREVIOUS BUILD
rm -rf "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

"${MESON:-meson}" setup "${BUILD_DIR}" \
  --cross-file="$CROSS_FILE" \
  --buildtype=release \
  --default-library=static \
  -Db_staticpic=true \
  -Db_lto=false \
  -Db_ndebug=if-release \
  -Dfft=builtin \
  -Dresampler=libsamplerate \
  -Dcmdline=disabled \
  -Djni=disabled \
  -Dvamp=disabled \
  -Dladspa=disabled \
  -Dlv2=disabled \
  -Dtests=disabled 1>>"${BASEDIR}"/build.log 2>&1 || return 1

cd "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

ninja -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

ninja install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp "${BUILD_DIR}"/meson-private/rubberband.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
