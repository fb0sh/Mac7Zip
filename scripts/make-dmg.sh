#!/usr/bin/env bash
# Package a built .app into a distributable DMG containing an /Applications shortcut.
# Usage: scripts/make-dmg.sh <path-to-.app> <output-dmg>
set -euo pipefail

APP="${1:?usage: make-dmg.sh <app-path> <output-dmg>}"
OUT="${2:?usage: make-dmg.sh <app-path> <output-dmg>}"
if [ ! -d "$APP" ]; then echo "::error::App not found: $APP"; exit 1; fi
APP_NAME="$(basename "$APP" .app)"

STAGE="$(dirname "$OUT")/.dmg-stage"
rm -rf "$STAGE"
trap 'rm -rf "$STAGE"' EXIT
VOL="$STAGE/volume"
mkdir -p "$VOL"

/usr/bin/ditto "$APP" "$VOL/$APP_NAME.app"
ln -s /Applications "$VOL/Applications"

rm -f "$OUT"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$VOL" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$OUT"

echo "--- verifying DMG ---"
/usr/bin/hdiutil verify "$OUT"
ls -lh "$OUT"
