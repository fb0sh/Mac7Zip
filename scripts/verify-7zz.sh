#!/usr/bin/env bash
# Verify the vendored 7zz binaries against pinned SHA-256 sums.
# Usage: scripts/verify-7zz.sh [--allow-missing]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Vendor/7zz/26.06"

if [ ! -f "$VENDOR/SHA256SUMS" ]; then
  echo "::error::Missing $VENDOR/SHA256SUMS"
  exit 1
fi

cd "$VENDOR"
echo "--- Verifying vendored 7zz binaries (7-Zip 26.06) ---"
cat SHA256SUMS

if command -v shasum >/dev/null 2>&1; then
  CHECK_CMD=(shasum -a 256 -c SHA256SUMS)
else
  CHECK_CMD=(sha256sum -c SHA256SUMS)
fi

if ! "${CHECK_CMD[@]}"; then
  echo "::error::7zz checksum mismatch — vendored binary does not match SHA256SUMS"
  exit 1
fi

echo "--- Architecture check ---"
for arch_dir in arm64 x86_64; do
  BIN="$VENDOR/$arch_dir/7zz"
  if [ ! -f "$BIN" ]; then
    echo "::error::Missing $BIN"
    exit 1
  fi
  INFO="$(file -b "$BIN")"
  echo "$arch_dir: $INFO"
  case "$arch_dir" in
    arm64)   echo "$INFO" | grep -q "arm64"   || { echo "::error::arm64 binary is not arm64"; exit 1; } ;;
    x86_64)  echo "$INFO" | grep -q "x86_64"  || { echo "::error::x86_64 binary is not x86_64"; exit 1; } ;;
  esac
done

echo "7zz verification OK"
