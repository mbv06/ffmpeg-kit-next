#!/bin/bash

# WEB (WASM) FREETYPE BUILD
# Autotools build via Emscripten. zlib comes from Emscripten's zlib port
# (-sUSE_ZLIB=1) like the libpng build; libpng (color emoji glyphs) was built
# earlier in the loop. brotli (woff2 fonts) is disabled on web: the other
# platforms get it from libjxl's bundled brotli, which is not built here.
# Static + PIC.

# PROVIDE ZLIB VIA THE EMSCRIPTEN PORT
export CFLAGS="${CFLAGS} -sUSE_ZLIB=1"
export LDFLAGS="${LDFLAGS} -sUSE_ZLIB=1"

# UPDATE BUILD FLAGS
export LIBPNG_CFLAGS="-I${LIB_INSTALL_BASE}/libpng/include"
export LIBPNG_LIBS="-L${LIB_INSTALL_BASE}/libpng/lib"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# autogen.sh defaults to Homebrew's glibtoolize on Darwin; the nix shell ships
# plain libtoolize, and autogen.sh honors this override
export LIBTOOLIZE="$(command -v glibtoolize || command -v libtoolize)"

# emcc-built conftest binaries run on the host via node, so without an explicit
# --build (passed to configure below) autoconf decides it is NOT cross-compiling
# and builds the native apinames tool with emcc — whose MEMFS output cannot reach
# the host filesystem. CC_BUILD gives the forced cross mode a native compiler.
export CC_BUILD="$(command -v cc || command -v clang || command -v gcc)"

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/configure ]] || [[ ${RECONF_freetype} -eq 1 ]]; then

  # NOTE THAT FREETYPE DOES NOT SUPPORT AUTORECONF BUT IT COMES WITH AN autogen.sh
  ./autogen.sh 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

emconfigure ./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-zlib \
  --with-png \
  --with-brotli=no \
  --without-harfbuzz \
  --without-bzip2 \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-mmap \
  --build="$("${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/config.guess)" \
  --host="${HOST}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1 || return 1

emmake make install 1>>"${BASEDIR}"/build.log 2>&1 || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_freetype_package_config "26.6.20" || return 1
