#!/bin/bash

# WEB (WASM) HARFBUZZ BUILD
# Meson build via a generated Emscripten cross file (meson ignores the
# CFLAGS/CXXFLAGS environment in cross builds, so the web flags are embedded in
# the cross file). harfbuzz is C++; its C++ runtime symbols stay undefined in the
# side modules and resolve at the main-module link, like x265. Depends on
# freetype (built earlier in the loop). Static + PIC.

# SET BUILD FLAGS
CROSS_FILE="${BASEDIR}"/src/"${LIB_NAME}"/package/crossfiles/$ARCH-$FFMPEG_KIT_BUILD_TYPE.meson

mkdir -p "$(dirname "$CROSS_FILE")" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
create_mason_cross_file "$CROSS_FILE" || return 1

"${MESON:-meson}" setup "${BUILD_DIR}" \
  --cross-file="$CROSS_FILE" \
  --buildtype=release \
  --default-library=static \
  -Db_staticpic=true \
  -Db_lto=false \
  -Db_ndebug=if-release \
  -Dfreetype=enabled \
  -Dglib=disabled \
  -Dgobject=disabled \
  -Dcairo=disabled \
  -Dchafa=disabled \
  -Dpng=disabled \
  -Dzlib=disabled \
  -Dicu=disabled \
  -Dgraphite=disabled \
  -Dgraphite2=disabled \
  -Dfontations=disabled \
  -Dgdi=disabled \
  -Ddirectwrite=disabled \
  -Dcoretext=disabled \
  -Dharfrust=disabled \
  -Dkbts=disabled \
  -Dwasm=disabled \
  -Draster=disabled \
  -Dvector=disabled \
  -Dgpu=disabled \
  -Dgpu_demo=disabled \
  -Dsubset=disabled \
  -Dtests=disabled \
  -Dintrospection=disabled \
  -Ddocs=disabled \
  -Dutilities=disabled \
  -Dbenchmark=disabled 1>>"${BASEDIR}"/build.log 2>&1 || return 1

cd "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

ninja -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

ninja install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# MANUALLY COPY PKG-CONFIG FILE
cp "${BUILD_DIR}"/meson-private/harfbuzz.pc "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
