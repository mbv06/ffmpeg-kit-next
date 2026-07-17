#!/bin/bash

display_help() {
  local COMMAND
  local PROFILE_USAGE=""
  local PROFILE_OPTION=""

  COMMAND=$(echo "$0" | sed -e 's/\.\///g')

  if [[ -n ${FFMPEG_KIT_NIX_HELP:-} ]]; then
    PROFILE_USAGE="[-p PROFILE] "
    PROFILE_OPTION="  -p, --profile PROFILE\t\tnix develop profile to use [web-wasm32-emscripten]\n      --list-profiles\t\tlist local nix develop profiles"
  fi

  echo -e "\n'$COMMAND' builds FFmpegKit for the WebAssembly browser target using Emscripten. \
The default target is wasm32-unknown-emscripten with WebAssembly SIMD enabled. The web C++ \
ffmpeg-kit wrapper currently requires Emscripten pthreads, so browser consumers must serve the \
final application with SharedArrayBuffer-compatible COOP/COEP headers when ffmpeg-kit is built.\n"
  echo -e "Usage: ./$COMMAND ${PROFILE_USAGE}[OPTION]...\n"
  echo -e "Specify environment variables as VARIABLE=VALUE to override default build options.\n"

  display_help_options "${PROFILE_OPTION}" "      --jobs=N\t\t\tnumber of jobs to run [auto]" "      --no-ffmpeg-kit-protocols\tdisable custom ffmpeg-kit protocols (ffkitmem, ffkitstream) [no]"
  display_help_licensing

  echo -e "Architectures:"
  echo -e "  --disable-wasm32\t\tdo not build wasm32 architecture [no]\n"

  echo -e "Web options:"
  echo -e "      --enable-pthreads\t\tbuild with Emscripten pthread support [yes]"
  echo -e "      --disable-pthreads\tbuild FFmpeg core without pthread support; requires --skip-ffmpeg-kit [no]"
  echo -e "      --enable-relaxed-simd\tadd -mrelaxed-simd for experimental optimized builds [no]\n"

  echo -e "Libraries:"
  echo -e "  External libraries wired for web so far: chromaprint, dav1d, fontconfig, freetype, fribidi, gmp, gnutls, harfbuzz,\n  kvazaar, lame, libaom, libass, libilbc, liblc3, libsamplerate, libsndfile, libtheora, libvidstab (GPL), libvorbis,\n  libvpx, libwebp, libxml2, nettle, opencore-amr, openssl, opus, openh264, rubberband (GPL), sdl, shine, snappy, soxr,\n  speex, srt, svtav1, tesseract, twolame, vo-amrwbenc, vvenc, x264 (GPL), x265 (GPL), xvidcore (GPL), zimg, libjxl,\n  expat, giflib, jpeg, leptonica, libpng, tiff.\n  Other libraries are untested under Emscripten and may fail to build.\n"

  display_help_custom_libraries
  display_help_advanced_options
}
