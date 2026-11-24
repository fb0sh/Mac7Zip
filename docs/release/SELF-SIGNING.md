# Self-signing (local use, no App Store)

Mac7Zip can be **ad-hoc signed** for local use without an Apple Developer account.
This runs on your own Mac (and machines that trust the file), but is **not**
notarized and is not intended for App Store distribution.

## What CI produces
- `Mac7Zip-selfsigned.zip` — the app with **ad-hoc signature** applied to the
  bundled `7zz` helper, the Finder Sync extension, and the app bundle, then verified
  with `codesign --verify --deep --strict` in CI.
- `Mac7Zip-universal.zip` — the same build **unsigned** (baseline).

## Install & run
```bash
unzip Mac7Zip-selfsigned.zip
# Gatekeeper: clear quarantine once (you built/trusted it yourself)
xattr -dr com.apple.quarantine Mac7Zip.app
open Mac7Zip.app
```

## Enable the Finder extension (first-level right-click menu)
```bash
# Register the extension with the system (run once)
pluginkit -a "Mac7Zip.app/Contents/PlugIns/Mac7ZipFinderSync.appex"
```
Then **System Settings ▸ General ▸ Login Items & Extensions ▸ Finder Extensions**
(or the "+"/checkbox list) and enable **Mac7Zip Finder**.
The menu appears for the monitored folders (Downloads / Documents / Desktop).

## Limits of ad-hoc signing
- Not notarized: on a *different* Mac, Gatekeeper may still block it; users would
  need to right-click ▸ Open or clear quarantine.
- Finder Sync requires code signing; ad-hoc works for local testing. A properly
  distributed extension (other machines) needs a Developer ID.

## Finder extension not showing? (troubleshooting)
1. Move `Mac7Zip.app` to `/Applications` and launch it once.
2. Run `scripts/enable-finder-extension.sh /Applications/Mac7Zip.app` (registers + enables via `pluginkit`).
3. Enable **Mac7Zip Finder** in System Settings ▸ General ▸ Login Items & Extensions ▸ Finder Extensions.
4. If it still doesn't load: Finder Sync extensions require a **code-signed** bundle; ad-hoc signing
   works for local testing on the same machine, but macOS may refuse unsigned/adhoc extensions on
   managed or newer systems. A Developer ID signature removes this limitation (M6-04/05).
