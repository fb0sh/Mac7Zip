#!/usr/bin/env bash
# Download + build libarchive as a universal (arm64+x86_64) static library for
# linking into Mac7Zip and its Quick Look extensions. BSD-2-Clause.
# Output: Vendor/libarchive-prefix/{include,lib/libarchive.a}
set -euo pipefail

VERSION="${LIBARCHIVE_VERSION:-3.7.7}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="$ROOT/Vendor/libarchive-prefix"
WORK="$ROOT/tmp/libarchive-build"
TARBALL="$WORK/libarchive-$VERSION.tar.gz"
URL="https://github.com/libarchive/libarchive/releases/download/v$VERSION/libarchive-$VERSION.tar.gz"

if [ -f "$PREFIX/lib/libarchive.a" ]; then
  echo "libarchive already built at $PREFIX"; exit 0
fi

mkdir -p "$WORK" "$PREFIX"
if [ ! -f "$TARBALL" ]; then
  echo "Downloading $URL"
  curl -fL --retry 3 -o "$TARBALL" "$URL"
fi
echo "sha256: $(shasum -a 256 "$TARBALL" | awk '{print $1}')"

SRC="$WORK/libarchive-$VERSION"
rm -rf "$SRC"
tar -xzf "$TARBALL" -C "$WORK"

cmake -S "$SRC" -B "$SRC/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DENABLE_TEST=OFF -DENABLE_CPIO=OFF -DENABLE_CAT=OFF -DENABLE_TAR=OFF -DENABLE_UNZIP=OFF \
  -DENABLE_OPENSSL=OFF -DENABLE_LIBB2=OFF -DENABLE_LZ4=OFF -DENABLE_ZSTD=OFF -DENABLE_LZO=OFF \
  -DENABLE_NETTLE=OFF -DENABLE_MBEDTLS=OFF
cmake --build "$SRC/build" --target archive_static -j 4
cmake --install "$SRC/build"

ls -l "$PREFIX/lib/libarchive.a"
lipo -info "$PREFIX/lib/libarchive.a" 2>/dev/null || echo "(lipo unavailable)"
