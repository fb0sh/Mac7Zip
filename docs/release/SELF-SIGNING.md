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
