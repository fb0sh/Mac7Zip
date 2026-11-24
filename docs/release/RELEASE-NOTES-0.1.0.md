# Mac7Zip 0.1.0

First preview release — **7-Zip's capability, Finder's native feel, macOS 26
interaction.**

## Highlights
- Browse, open and extract 7z/ZIP/TAR/GZ archives with real archive columns.
- Create 7z/ZIP archives with presets and advanced parameters.
- Fail-closed extraction safety (traversal/zip-bomb/symlink protection).
- Copy/move/duplicate, drag in/out of Finder, Finder tags, favourites, dual-pane.
- Native Settings, Quick Look, Finder Services, notifications, About/licenses.

## Known limitations
- **RAR creation is not supported** (unRAR license) — extraction only.
- **Password-protected archives are not openable yet** (secure password transport
  pending; see ADR-005). The app refuses rather than exposing passwords.
- Notarized distribution requires Apple Developer credentials (tracked separately).

## Requirements
- macOS 26 or later. Apple silicon recommended; Intel via Rosetta.
