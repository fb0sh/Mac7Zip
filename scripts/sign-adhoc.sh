#!/usr/bin/env bash
# Ad-hoc / self-sign the app for local use (no Apple Developer account, no App Store).
# Signs inner components first (helper, Finder extension) then the app bundle.
# Usage: scripts/sign-adhoc.sh <path-to-.app>
set -euo pipefail

APP="${1:?usage: sign-adhoc.sh <app-path>}"
if [ ! -d "$APP" ]; then echo "::error::App not found: $APP"; exit 1; fi

sign() { /usr/bin/codesign --force --sign - --timestamp=none "$1"; }

echo "--- signing helper executables ---"
if [ -d "$APP/Contents/Helpers" ]; then
  while IFS= read -r -d '' bin; do
    echo "sign helper: $bin"; sign "$bin"
  done < <(find "$APP/Contents/Helpers" -type f -perm -111 -print0)
fi

echo "--- signing embedded extensions ---"
if [ -d "$APP/Contents/PlugIns" ]; then
  while IFS= read -r -d '' appex; do
    if [ -d "$appex/Contents/MacOS" ]; then
      while IFS= read -r -d '' exe; do echo "sign ext exe: $exe"; sign "$exe"; done < <(find "$appex/Contents/MacOS" -type f -print0)
    fi
    echo "sign appex: $appex"; sign "$appex"
  done < <(find "$APP/Contents/PlugIns" -maxdepth 1 -name '*.appex' -print0)
fi

echo "--- signing app bundle ---"
sign "$APP"

echo "--- verifying ---"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
/usr/bin/codesign -dv --verbose=2 "$APP" 2>&1 | grep -E 'Identifier|Signature|TeamIdentifier|flags' || true
echo "ad-hoc signing OK"
