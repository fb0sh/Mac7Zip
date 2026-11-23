# Changelog

All notable changes to Mac7Zip are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/), versioning follows SemVer.

## [Unreleased]

## [0.1.0] — 2026-11-23
### Added
- Native macOS file browser (M1): sortable list, sidebar, path bar, status bar.
- Archive read & extract (M2): vendored 7-Zip 26.06 engine, fail-closed security
  validator, staged extraction, archive browsing with archive-specific columns,
  integrity test, extract-options sheet, Tasks UI.
- Compression (M3): create 7z/ZIP with level/format/advanced parameters, atomic
  output, conflict handling.
- File management (M4): copy/move/duplicate with conflict policies, drag in/out,
  metadata & permissions, Finder tags, favourites, dual-pane.
- macOS integration (M5): document types & Open With, Settings (double-click
  Open/Extract, limits), Quick Look, Finder Services, notifications, About/licenses,
  window restoration.
### Security
- Extraction is fail-closed: traversal, absolute/symlink escapes, ratio bombs and
  oversize archives are refused with no writes outside the destination.
- Password transport is **fail-closed by default** (7-Zip's prompt is console-bound;
  see ADR-005). No silent `ps`-visible fallback.
