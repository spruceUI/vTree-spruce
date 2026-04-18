#!/bin/bash
set -e

VTREE_VERSION="${VTREE_VERSION:-master}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
CROSS=aarch64-linux-gnu

export CC=${CROSS}-gcc
export PKG_CONFIG_PATH=/usr/lib/${CROSS}/pkgconfig
export PKG_CONFIG_LIBDIR=/usr/lib/${CROSS}/pkgconfig

# ccache setup
export CCACHE_DIR="${CCACHE_DIR:-/ccache}"
export PATH="/usr/lib/ccache:$PATH"
ln -sf /usr/bin/ccache /usr/local/bin/${CROSS}-gcc
ccache --max-size=200M
ccache --zero-stats

echo "=== Building vTree ${VTREE_VERSION} for aarch64 ==="

git clone https://github.com/MustardOS/vtree.git
cd vtree
if [ "$VTREE_VERSION" != "master" ]; then
    git checkout "$VTREE_VERSION"
fi

# Apply common patches
if [ -d /patches/common ] && ls /patches/common/*.patch 1>/dev/null 2>&1; then
    for patch in /patches/common/*.patch; do
        echo "Applying: $(basename "$patch")"
        git apply "$patch"
    done
fi

# vTree's Makefile leaves SDL2_CFLAGS empty — supply it via make override
# so headers are found in the multiarch SDL2 directory.
SDL_CFLAGS="$(pkg-config --cflags sdl2 SDL2_ttf SDL2_image)"

make release CC=${CROSS}-gcc SDL2_CFLAGS="$SDL_CFLAGS"
${CROSS}-strip -s vtree

# ============================================================
# Collect output
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

echo "=== ccache stats ==="
ccache --show-stats

echo "=== Build complete ==="
ls -la "$OUTPUT_DIR/"
