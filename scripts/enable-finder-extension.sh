#!/usr/bin/env bash
# Register + enable the Mac7Zip Finder Sync extension for the current user.
# Usage: scripts/enable-finder-extension.sh "/path/to/Mac7Zip.app"
set -euo pipefail
APP="${1:?usage: enable-finder-extension.sh <Mac7Zip.app>}"
APPEX="$APP/Contents/PlugIns/Mac7ZipFinderSync.appex"
BUNDLE_ID="com.fb0sh.Mac7Zip.FinderSync"

if [ ! -d "$APPEX" ]; then echo "::error::Extension not found at $APPEX"; exit 1; fi

echo "--- codesign (extension) ---"
codesign --verify --deep --strict "$APPEX" && codesign -dv "$APPEX" 2>&1 | grep -E 'Identifier|Signature' || true

echo "--- registering with pluginkit ---"
pluginkit -a "$APPEX" || true
pluginkit -e use -i "$BUNDLE_ID" || true
echo "--- current registration ---"
pluginkit -m -i "$BUNDLE_ID" || true

echo
echo "Now enable it in: System Settings ▸ General ▸ Login Items & Extensions ▸ Finder Extensions → Mac7Zip Finder"
echo "(If it still doesn't appear, move Mac7Zip.app to /Applications and relaunch it once.)"
