#!/usr/bin/env bash
# Bundle the 7zz helper and its license into the built .app bundle.
# Usage: scripts/bundle-7zz.sh <path-to-.app> <arm64|x86_64|universal>
set -euo pipefail

APP_PATH="${1:?usage: bundle-7zz.sh <app-path> <arch>}"
ARCH="${2:-arm64}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Vendor/7zz/26.06"

if [ ! -d "$APP_PATH" ]; then
  echo "::error::App bundle not found: $APP_PATH"
  exit 1
fi

HELPERS="$APP_PATH/Contents/Helpers"
RESOURCES="$APP_PATH/Contents/Resources"
mkdir -p "$HELPERS" "$RESOURCES"

case "$ARCH" in
  arm64)
    cp "$VENDOR/arm64/7zz" "$HELPERS/7zz"
    ;;
  x86_64)
    cp "$VENDOR/x86_64/7zz" "$HELPERS/7zz"
    ;;
  universal)
    lipo -create -output "$HELPERS/7zz" "$VENDOR/arm64/7zz" "$VENDOR/x86_64/7zz"
    ;;
  *)
    echo "::error::Unknown arch: $ARCH"
    exit 1
    ;;
esac

chmod 755 "$HELPERS/7zz"
cp "$VENDOR/License.txt" "$RESOURCES/7zz-LICENSE.txt"
cp "$VENDOR/readme.txt" "$RESOURCES/7zz-README.txt"

echo "--- Bundled helper ---"
file "$HELPERS/7zz"
ls -l "$HELPERS/7zz"
