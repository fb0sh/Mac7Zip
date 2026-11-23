# Tickets Index

**Status:** Living · **Last updated:** 2026-11-23

> **中文摘要**：工单索引——列出全部工单（M1–M3 为可实施级，M4–M6 为 Epic 级）、优先级、类型、依赖关系与可并行性。Markdown 为权威来源，GitHub Issues 可选镜像。

Ticket files: [M1](m1-file-browser-core.md) · [M2](m2-archive-read-extract.md) · [M3](m3-compression.md) · [EPIC-M4](epic-m4-file-management.md) · [EPIC-M5](epic-m5-macos-integration.md) · [EPIC-M6](epic-m6-release-hardening.md)

## Status

All MVP tickets are **Planned** (not started). No feature implementation has begun.

## M1 — File Browser Core (MVP)

| ID | Title | Pri | Type | Depends on |
|---|---|---|---|---|
| TKT-M1-01 | Foundation refactor: FileSystemProvider + BrowserStore + FileAccess | P0 | Refactor | — |
| TKT-M1-02 | File-list performance: snapshot, icon cache, benchmark | P0 | Feature | M1-01 |
| TKT-M1-03 | Navigation & history on BrowserLocation | P1 | Feature | M1-01 |
| TKT-M1-04 | Selection, sorting, status totals | P1 | Feature | M1-01 |
| TKT-M1-05 | New Folder / Rename / Delete (Trash) | P0 | Feature | M1-01, M1-06 |
| TKT-M1-06 | FileOperationsService scaffold + typed errors | P0 | Refactor | M1-01 |
| TKT-M1-07 | Load states + access-denied/TCC UX | P0 | Feature | M1-01 |
| TKT-M1-08 | Keyboard shortcuts & context menus | P1 | Feature | M1-03, M1-04, M1-05 |
| TKT-M1-09 | Tests: FS core, ops, performance | P0 | Test | M1-01…07 |
| TKT-M1-10 | CI hardening: lint, arch/dependency check, XCUITest spike | P1 | Infrastructure | M1-01 |

## M2 — Archive Read & Extract (MVP)

| ID | Title | Pri | Type | Depends on |
|---|---|---|---|---|
| TKT-M2-01 | Vendor 7zz (pinned, checksum, license, nested signing) | P0 | Infrastructure | — |
| TKT-M2-02 | SevenZipEngine process runner | P0 | Feature | M2-01 |
| TKT-M2-03 | Output adapter & parsers (+ golden fixtures) | P0 | Feature | M2-02 |
| TKT-M2-04 | ArchiveFileSystemProvider (read-only) | P0 | Feature | M1-01, M2-03 |
| TKT-M2-05 | Enter/navigate archive in browser | P0 | Feature | M2-04 |
| TKT-M2-06 | SecurityValidator (pre-flight + limits) | P0 | Feature | M2-03 |
| TKT-M2-07 | Extract all/selected pipeline + UI | P0 | Feature | M2-02, M2-06, M2-08 |
| TKT-M2-08 | TaskCenter + Tasks popover/progress | P0 | Feature | M2-02 |
| TKT-M2-09 | Cancellation & cleanup | P0 | Feature | M2-08 |
| TKT-M2-10 | Test integrity + password prompt flow | P1 | Feature | M2-02, M2-03 |
| TKT-M2-11 | Integration & security tests + fixtures | P0 | Test | M2-06, M2-07, M2-09 |
| TKT-M2-12 | Drag-out-to-Finder extraction | P0 | Feature | M2-04, M2-06, M2-07 |
| TKT-M2-13 | Archive activation preference (Open vs Extract) | P1 | Feature | M2-07, M1-08 |

## M3 — Compression (MVP)

| ID | Title | Pri | Type | Depends on |
|---|---|---|---|---|
| TKT-M3-01 | Create-archive core command + option mapping | P0 | Feature | M2-02 |
| TKT-M3-02 | Compression dialog (SwiftUI form) + validation | P0 | Feature | M3-01 |
| TKT-M3-03 | Password/encryption + secure handling | P1 | Feature | M3-01 |
| TKT-M3-04 | Target conflict + destination validation | P0 | Feature | M3-01 |
| TKT-M3-05 | Compression progress/cancel + completion feedback | P0 | Feature | M3-01, M2-08 |
| TKT-M3-06 | Advanced options (multi-volume, method, threads) | P2 | Feature | M3-01 |
| TKT-M3-07 | Round-trip integration tests | P0 | Test | M3-01…05 |

## Epics (M4–M6)

| ID | Title | Pri |
|---|---|---|
| EPIC-M4 | File-Management Enhancements (copy/move/drag-drop/favourites/dual-pane) | P1 |
| EPIC-M5 | macOS Integration (associations, Open With, Quick Look, notifications, settings) | P1 |
| EPIC-M6 | Performance, Security & Release Hardening (universal, signing, notarization, DMG, releases) | P0 for release |

## Parallelizable tracks

- **Track A (UI/State):** M1-02/03/04/07/08 can run in parallel after M1-01.
- **Track B (Engine):** M2-01→02→03 is a hard chain; M2-06 (security) can start after M2-03.
- **Track C (Tasks/UI):** M2-08/09 parallel with M2-04/05 once M2-02 lands.
- **Track D (Compression):** M3-01…05 serial-ish; M3-06 (P2) anytime after M3-01.
- **Track E (CI):** M1-10 parallel from day one.
