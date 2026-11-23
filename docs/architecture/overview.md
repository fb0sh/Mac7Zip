# Mac7Zip — Architecture Overview

**Status:** Living document · **Last updated:** 2026-11-23 · **Owner:** Architecture

> **中文摘要**：本文是 Mac7Zip 的架构总览与文档索引，说明分层边界、目录约定、ID 命名规则与 ADR/Spec/Ticket 的双向追踪矩阵。它是理解其余全部设计文档的入口。

This document is the entry point for Mac7Zip's engineering design. It describes the system's layers, the conventions used across all planning documents, and the single authoritative **traceability matrix** linking architecture decisions → specifications → executable tickets.

Mac7Zip is **Phase 0 complete** (native SwiftUI/AppKit shell, file browser, CI on `macos-26`). This planning set covers **Phases 1–5**, reorganized into milestones **M1–M6** with an archive-centric MVP.

---

## 1. System context

Mac7Zip is a native macOS 26+ archive manager with professional file-management capabilities. It is a single `.app` bundle that runs a bundled `7zz` helper as a managed subprocess. There is no backend service, no network dependency at runtime, and no Electron/WebView.

```
┌──────────────────────────────────────────────────────────────┐
│ Mac7Zip.app                                                   │
│                                                              │
│  ┌─────────────────────────── UI Layer ────────────────────┐ │
│  │ SwiftUI scene(s) · NavigationSplitView · Toolbar · Menus │ │
│  │ SwiftUI forms (Compression dialog) · Tasks popover        │ │
│  │ ── NSViewRepresentable boundary ──                        │ │
│  │ AppKit: NSTableView file list, NSWindow/panel integration │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            │ commands / observed state        │
│  ┌─────────────────────── State Layer ─────────────────────┐ │
│  │ BrowserStore (per window): location, history, selection, │ │
│  │ sort · TaskCenter (actor): queued/running tasks, progress │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            │ protocol calls                    │
│  ┌────────────── Domain / Service Layer ───────────────────┐ │
│  │ FileSystemProvider (real | archive, capabilities)        │ │
│  │ FileOperationsService · ArchiveEngine (7zz impl)         │ │
│  │ FileAccess (permissions boundary) · SecurityValidator    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            │ Process / FileManager            │
│  ┌──────────────────── Infrastructure ──────────────────────┐ │
│  │ /usr/bin process (bundled 7zz) · FileManager · temp dirs │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## 2. Layer responsibilities

| Layer | Owns | Must not own |
|---|---|---|
| **UI** | Windows, navigation chrome, SwiftUI views, AppKit adapters, dialogs, menu/toolbar wiring, presentation state | Filesystem logic, process parsing, security decisions |
| **State** | `BrowserStore` (per window) and `TaskCenter` (global actor); observable state machines | Direct disk or process access |
| **Domain/Services** | `FileSystemProvider`, `FileOperationsService`, `ArchiveEngine`, `SecurityValidator`, `FileAccess` | SwiftUI/AppKit types |
| **Infrastructure** | `Process` execution, `FileManager`, temp/staging directories, bundled `7zz` | Business policy |

Dependency direction is strictly downward. Domain code is **SwiftUI-free and AppKit-free** where practical so it is unit-testable without a host app (see ADR-003/ADR-010).

## 3. Documentation map

```
docs/
├── architecture/
│   ├── overview.md                    ← this file (index + traceability matrix)
│   └── adr/
│       ├── 0001-swiftui-appkit-responsibilities.md
│       ├── 0002-file-list-control-and-performance.md
│       ├── 0003-file-manager-state-and-navigation.md
│       ├── 0004-archive-engine-selection-and-abstraction.md
│       ├── 0005-7zz-process-task-scheduling-cancellation.md
│       ├── 0006-archive-virtual-filesystem.md
│       ├── 0007-file-permissions-sandbox-and-access.md
│       ├── 0008-archive-extraction-security-model.md
│       ├── 0009-engine-distribution-license-and-packaging.md
│       └── 0010-github-actions-build-test-release.md
├── specs/
│   ├── index.md
│   ├── file-manager.md            (SPEC-FM)
│   ├── archive-engine.md          (SPEC-AE)
│   ├── archive-browser.md         (SPEC-AB)
│   ├── compression.md             (SPEC-CW)
│   ├── task-management.md         (SPEC-TM)
│   ├── security.md                (SPEC-SEC)
│   └── release.md                 (SPEC-REL)
├── tickets/
│   ├── index.md
│   ├── m1-file-browser-core.md
│   ├── m2-archive-read-extract.md
│   ├── m3-compression.md
│   ├── epic-m4-file-management.md
│   ├── epic-m5-macos-integration.md
│   └── epic-m6-release-hardening.md
└── roadmap.md
```

## 4. Identifier conventions

| Kind | Pattern | Example |
|---|---|---|
| ADR | `ADR-0NN` (file `0NNN-slug.md`, four digits) | `ADR-004` |
| Spec | `SPEC-<AREA>` | `SPEC-AE` |
| Ticket | `TKT-M<n>-<nn>` | `TKT-M2-04` |
| Epic | `EPIC-M<n>` | `EPIC-M4` |
| Milestone | `M1 … M6` | `M2` |

Every ticket names its `Related Spec` and `Related ADR`. Every ADR names the specs/tickets it governs. Every spec lists upstream ADRs and downstream tickets. The matrix below is the canonical roll-up; the per-document links are authoritative detail.

## 5. Traceability matrix (authoritative)

| Concern | ADR | Spec | Primary Tickets |
|---|---|---|---|
| SwiftUI/AppKit split | ADR-001 | SPEC-FM, SPEC-AB | TKT-M1-01, TKT-M1-02, TKT-M2-05 |
| File-list control & performance | ADR-002 | SPEC-FM | TKT-M1-02, TKT-M6-01 |
| State model & navigation | ADR-003 | SPEC-FM | TKT-M1-01, TKT-M1-03, TKT-M1-04 |
| Archive engine selection & abstraction | ADR-004 | SPEC-AE | TKT-M2-02, TKT-M2-03 |
| 7zz process / task scheduling / cancel | ADR-005 | SPEC-TM, SPEC-AE | TKT-M2-08, TKT-M2-09 |
| Archive virtual filesystem | ADR-006 | SPEC-AB | TKT-M1-01, TKT-M2-04, TKT-M2-05 |
| Permissions / Sandbox / access | ADR-007 | SPEC-SEC | TKT-M1-07, TKT-M5-02 |
| Extraction security model | ADR-008 | SPEC-SEC | TKT-M2-06, TKT-M2-07, TKT-M2-11 |
| Engine distribution / license / packaging | ADR-009 | SPEC-REL, SPEC-AE | TKT-M2-01, TKT-M6-04 |
| CI build / test / release | ADR-010 | SPEC-REL | TKT-M1-10, TKT-M6-02, TKT-M6-03 |
| Compression workflow | ADR-004, ADR-009 | SPEC-CW | TKT-M3-01 … TKT-M3-07 |
| File operations (copy/move/drag) | ADR-003, ADR-007 | SPEC-FM | EPIC-M4 tickets |
| macOS integration | ADR-010 | SPEC-REL, SPEC-AB | EPIC-M5 tickets |

## 6. Status vocabulary

- **Accepted** — decided; implementation may proceed.
- **Proposed** — direction chosen but pending a spike, credentials, or measurement; may change.
- **Superseded** — replaced by a later ADR (link preserved).

Unresolved technical details are recorded as explicit **Assumptions/Risks** in the relevant ADR/Spec rather than left implicit.

## 7. Change process

1. A new significant decision gets a new ADR (never rewrite history; supersede).
2. Requirement changes edit the owning Spec and update Acceptance Criteria.
3. Work items live in `docs/tickets/`; GitHub Issues may mirror them but the markdown is authoritative.
4. Any change updates the traceability matrix here and the ticket index in the same PR.
