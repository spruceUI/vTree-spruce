#!/bin/bash
set -e

VTREE_VERSION="${VTREE_VERSION:-master}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

# aemiii91/miyoomini-toolchain
TOOLCHAIN=/opt/miyoomini-toolchain
CROSS=arm-linux-gnueabihf
export PATH="$TOOLCHAIN/usr/bin:$PATH"
export CC="${CROSS}-gcc"
export STRIP="${CROSS}-strip"

# SDL2 headers come from the aemiii91 toolchain (ABI-compatible with the
# custom spruce SDL2), but we link against the spruce libraries directly.
SPRUCE_LIBS=/opt/spruce-mini-libs

SYSROOT="$($TOOLCHAIN/usr/bin/${CROSS}-gcc -print-sysroot 2>/dev/null || echo "$TOOLCHAIN/arm-linux-gnueabihf/libc")"

CFLAGS_COMMON="-O2 -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -fomit-frame-pointer -ffunction-sections -fdata-sections"
LDFLAGS_COMMON="-Wl,--gc-sections"

echo "=== Building vTree ${VTREE_VERSION} for Miyoo Mini (armhf) ==="

git clone https://github.com/MustardOS/vtree.git
cd vtree
if [ "$VTREE_VERSION" != "master" ]; then
    git checkout "$VTREE_VERSION"
fi

for dir in /patches/common /patches/miyoomini; do
    if [ -d "$dir" ] && ls "$dir"/*.patch 1>/dev/null 2>&1; then
        for patch in "$dir"/*.patch; do
            echo "Applying: $(basename "$patch")"
            git apply "$patch"
        done
    fi
done

# Upstream Makefile omits lang.c from SRCS — add it
sed -i 's|^\(SRCS[[:space:]]*:=.*\)$|\1 lang.c|' Makefile

# SDL_clamp compat shim (harmless on SDL >= 2.24)
cat > sdl_compat.h <<'EOF'
#ifndef SDL_clamp
#define SDL_clamp(x, a, b) (((x) < (a)) ? (a) : (((x) > (b)) ? (b) : (x)))
#endif
EOF

SDL_CFLAGS="-I$SYSROOT/usr/include -I$SYSROOT/usr/include/SDL2 -D_REENTRANT -include ./sdl_compat.h"
# Link against spruce's custom SDL2 stack; DT_NEEDED will record libSDL2-2.0.so.0
SDL_LIBS="-L$SPRUCE_LIBS -Wl,-rpath-link,$SPRUCE_LIBS -lSDL2_ttf -lSDL2_image -lSDL2 -lm"

make release CC=${CROSS}-gcc \
    SDL2_CFLAGS="$SDL_CFLAGS" \
    SDL2_LIBS="$SDL_LIBS" \
    CFLAGS_REL="-Wall -Wextra -std=c99 $SDL_CFLAGS -DSDL_MAIN_HANDLED -D_POSIX_C_SOURCE=200809L -O2 -DNDEBUG $CFLAGS_COMMON" \
    LDFLAGS_REL="$LDFLAGS_COMMON"

${STRIP} -s vtree

# ============================================================
# Collect output — binary + runtime assets only
# (spruce already ships SDL2 stack in miyoo/lib/, no need to bundle)
# ============================================================
echo "=== Collecting output ==="
mkdir -p "$OUTPUT_DIR"
cp vtree "$OUTPUT_DIR/"
[ -d res ]                      && cp -r res "$OUTPUT_DIR/"
[ -d fonts ]                    && cp -r fonts "$OUTPUT_DIR/"
[ -f config.ini ]               && cp config.ini "$OUTPUT_DIR/"
[ -f theme.ini ]                && cp theme.ini "$OUTPUT_DIR/"
[ -f gamecontrollerdb.txt ]     && cp gamecontrollerdb.txt "$OUTPUT_DIR/"
[ -f LICENSE ]                  && cp LICENSE "$OUTPUT_DIR/"
[ -f README.md ]                && cp README.md "$OUTPUT_DIR/"

echo "=== DT_NEEDED entries ==="
${CROSS}-readelf -d "$OUTPUT_DIR/vtree" | grep NEEDED || true

echo "=== Build complete ==="
ls -la "$OUTPUT_DIR/"
