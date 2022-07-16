#!/bin/bash
set -euo pipefail

fn_git_clean() {
  git clean -xdf
  git checkout .
}

OUT_DIR="$PWD/out"
ROOT="$PWD"
EMCC_FLAGS_DEBUG="-Os -g3"
EMCC_FLAGS_RELEASE="-Oz -flto"
PDFium_BRANCH="chromium/5079"

export CPPFLAGS="-I$OUT_DIR/include -I$EMSDK/upstream/emscripten/cache/sysroot/include"
export LDFLAGS="-L$OUT_DIR/lib"
export PKG_CONFIG_PATH="$OUT_DIR/lib/pkgconfig"
export EM_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
export CFLAGS="$EMCC_FLAGS_RELEASE"
export CXXFLAGS="$CFLAGS"

mkdir -p "$OUT_DIR"

# inspired by https://github.com/bblanchon/pdfium-binaries
cd "$ROOT/lib/pdfium"
export PATH="$PATH:/src/lib/depot_tools"
gclient config --unmanaged .
gclient sync -r "origin/${PDFium_BRANCH:-main}" --no-history --shallow --force
patch -p1 <$ROOT/patches/pdfium/pdfium.patch
cd build
patch -p1 <$ROOT/patches/pdfium/build.patch
cd ..
mkdir -p "build/toolchain/wasm"
cp "$ROOT/patches/pdfium/toolchain.gn" "build/toolchain/wasm/BUILD.gn"
mkdir -p "build/config/wasm"
cp "$ROOT/patches/pdfium/config.gn" "build/config/wasm/BUILD.gn"
mkdir -p out
cp "$ROOT/pdfium.gn" out/args.gn
gn gen out
ninja -C out pdfium
cp $ROOT/lib/pdfium/public/*.h "$OUT_DIR/include/"
cp "$ROOT/lib/pdfium/out/obj/libpdfium.a" "$OUT_DIR/lib/"
cat > $OUT_DIR/lib/pkgconfig/pdfium.pc << EOF
     prefix=$OUT_DIR
     exec_prefix=\${prefix}
     libdir=\${exec_prefix}/lib
     includedir=\${prefix}/include
     Name: pdfium
     Description: pdfium
     Version: 4969
     Requires:
     Libs: -L\${libdir} -lpdfium
     Cflags: -I\${includedir}
EOF

cp "$ROOT/gxx_personality_v0_stub.cpp" "$OUT_DIR"
cd "$OUT_DIR"
emcc -c gxx_personality_v0_stub.cpp

mkdir -p "$ROOT/dist"
cd "$ROOT/lib/pdfr"
export BINDGEN_EXTRA_CLANG_ARGS="$CPPFLAGS"
export RUSTFLAGS=\
"-Clink-arg=$OUT_DIR/gxx_personality_v0_stub.o "\
"-Clink-arg=--pre-js=$ROOT/js/pre.js "\
"-Clink-arg=--post-js=$ROOT/js/post.js "\
"-Clink-arg=--closure=1 "\
"-Clink-arg=-sWASM_BIGINT=1 "\
"-Clink-arg=-sEXIT_RUNTIME=0 "\
"-Clink-arg=-sALLOW_MEMORY_GROWTH=1 "\
"-Clink-arg=-sEXPORTED_RUNTIME_METHODS=['callMain','FS','NODEFS','WORKERFS','ENV'] "\
"-Clink-arg=-sINCOMING_MODULE_JS_API=['noInitialRun','noFSInit','locateFile','preRun'] "\
"-Clink-arg=-sNO_DISABLE_EXCEPTION_CATCHING=1 "\
"-Clink-arg=-sMODULARIZE=1 "\
"-Clink-arg=-o$ROOT/dist/pdfr.js "\
"-Clink-arg=-lnodefs.js "\
"-Clink-arg=-lworkerfs.js "\
"-Clink-arg=-L$OUT_DIR/lib "
cargo build --target wasm32-unknown-emscripten --release
