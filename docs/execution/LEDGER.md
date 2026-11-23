# Mac7Zip — Implementation Execution Ledger

**Status:** Living · **Updated:** 2026-11-23 · **Policy:** batch implementation of M1–M6 authorized

> **中文摘要**：可恢复的执行账本。记录每张票的状态、issue、依赖、分支/PR、CI 证据与阻塞项；新会话从此处恢复，按依赖前沿推进。

## Operating rules
- Work in **dependency order** (frontier), not issue-number order.
- Markdown tickets = approved scope; GitHub Issues = execution record. Mapping: `docs/tickets/github-issues.md`.
- A ticket is DONE only when implemented + acceptance met + tests pass + CI evidence + docs/traceability updated.
- Do not report incomplete work as complete. Record blockers explicitly.

## Milestone status
| Milestone | Scope | State |
|---|---|---|
| M1 File Browser Core | 12 tickets | In progress (8 implemented) |
| M2 Archive Read & Extract | 15 tickets | Not started |
| M3 Compression | 8 tickets | Not started |
| M4 File-Management Enhancements | 9 tickets (incl. deferred TKT-M2-12) | Not started |
| M5 macOS Integration | 8 tickets | Not started |
| M6 Performance/Security/Release | 8 tickets | Not started (M6-04/05 external-blocked) |

## Next eligible work
- **`TKT-M1-08` (#9)** (shortcuts/context menu — now unblocked by M1-03/04/05), **`TKT-M1-10` (#11)** (CI hardening).
- After M1-08: **`TKT-M1-09` (#10)**, **`TKT-M1-12` (#57)**.
- **`TKT-M2-01` (#12)** — 7zz packaging spike; no blockers; may proceed in parallel.

## Tickets
| Ticket | Milestone | Status | Issue | Dependencies | Branch/PR | CI | Blockers |
|---|---|---|---|---|---|---|---|
| TKT-M1-01 — Foundation refactor: FileSystemProvider + BrowserStore + FileAccess | M1 | Implemented/verified (integration) | #2 | None. | integration/m1-m6 / PR #62 | [run 45130961718](https://github.com/fb0sh/Mac7Zip/actions/runs/45130961718) — 25 tests, build+release OK | — |
| TKT-M1-02 — File-list performance: snapshot, icon cache, benchmark | M1 | Implemented/verified (integration) | #3 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45132417806](https://github.com/fb0sh/Mac7Zip/actions/runs/45132417806) — 38 tests OK | — |
| TKT-M1-03 — Navigation & history on BrowserLocation | M1 | Implemented/verified (integration) | #4 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45131436860](https://github.com/fb0sh/Mac7Zip/actions/runs/45131436860) — 37 tests OK | — |
| TKT-M1-04 — Selection, sorting, status totals | M1 | Implemented/verified (integration) | #5 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45131436860](https://github.com/fb0sh/Mac7Zip/actions/runs/45131436860) — 37 tests OK | — |
| TKT-M1-05 — New Folder / Rename / Delete (Trash) | M1 | Implemented/verified (integration) | #6 | TKT-M1-01, TKT-M1-06. | integration/m1-m6 / PR #62 | [run 45132417806](https://github.com/fb0sh/Mac7Zip/actions/runs/45132417806) — 38 tests OK | — |
| TKT-M1-06 — FileOperationsService scaffold + typed errors | M1 | Implemented/verified (integration) | #7 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45131436860](https://github.com/fb0sh/Mac7Zip/actions/runs/45131436860) — 37 tests OK | — |
| TKT-M1-07 — Load states + access-denied/TCC UX | M1 | Implemented/verified (integration) | #8 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45131858152](https://github.com/fb0sh/Mac7Zip/actions/runs/45131858152) — 37 tests OK | — |
| TKT-M1-08 — Keyboard shortcuts & context menus | M1 | Planned | #9 | TKT-M1-03, TKT-M1-04, TKT-M1-05. | — | — | — |
| TKT-M1-09 — Tests: FS core, ops, performance | M1 | Planned | #10 | TKT-M1-01…07. | — | — | — |
| TKT-M1-10 — CI hardening: lint, arch/dependency check, XCUITest spike | M1 | Planned | #11 | TKT-M1-01. | — | — | — |
| TKT-M1-11 — Column widths adjustable & persisted | M1 | Implemented/verified (integration) | #56 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45131858152](https://github.com/fb0sh/Mac7Zip/actions/runs/45131858152) — 37 tests OK | — |
| TKT-M1-12 — Accessibility pass (VoiceOver + full keyboard) | M1 | Planned | #57 | TKT-M1-04, TKT-M1-08. | — | — | — |
| TKT-M2-01 — Vendor 7zz (pinned, checksum, license, nested signing) | M2 | Planned | #12 | None (blocking for M2). | — | — | — |
| TKT-M2-02 — SevenZipEngine process runner | M2 | Planned | #13 | TKT-M2-01. | — | — | — |
| TKT-M2-03 — Output adapter & parsers (+ golden fixtures) | M2 | Planned | #14 | TKT-M2-02. | — | — | — |
| TKT-M2-04 — ArchiveFileSystemProvider (read-only) | M2 | Planned | #15 | TKT-M1-01, TKT-M2-03. | — | — | — |
| TKT-M2-05 — Enter/navigate archive in browser | M2 | Planned | #16 | TKT-M2-04. | — | — | — |
| TKT-M2-06 — SecurityValidator (pre-flight + limits) | M2 | Planned | #17 | TKT-M2-03. | — | — | — |
| TKT-M2-07 — Extract all/selected pipeline + UI | M2 | Planned | #18 | TKT-M2-02, TKT-M2-06, TKT-M2-08, TKT-M2-09. | — | — | — |
| TKT-M2-08 — TaskCenter + Tasks popover/progress | M2 | Planned | #19 | TKT-M2-02. | — | — | — |
| TKT-M2-09 — Cancellation & cleanup | M2 | Planned | #20 | TKT-M2-08. | — | — | — |
| TKT-M2-10 — Test integrity + password prompt flow | M2 | Planned | #21 | TKT-M2-02, TKT-M2-03. | — | — | — |
| TKT-M2-11 — Integration & security tests + fixtures | M2 | Planned | #22 | TKT-M2-06, TKT-M2-07, TKT-M2-09. | — | — | — |
| TKT-M2-13 — Archive activation preference (Open vs Extract) | M2 | Planned | #24 | TKT-M2-07 (extraction), TKT-M1-08 (activation handling). | — | — | — |
| TKT-M2-14 — Archive-specific columns in archive browser | M2 | Planned | #58 | TKT-M2-03, TKT-M2-05. | — | — | — |
| TKT-M2-15 — Extract options sheet | M2 | Planned | #59 | TKT-M2-05, TKT-M2-06, TKT-M2-07. | — | — | — |
| TKT-M2-16 — Rich task progress metrics | M2 | Planned | #60 | TKT-M2-08. | — | — | — |
| TKT-M3-01 — Create-archive core command + option mapping | M3 | Planned | #25 | TKT-M2-02. | — | — | — |
| TKT-M3-02 — Compression dialog (SwiftUI form) + validation | M3 | Planned | #26 | TKT-M3-01. | — | — | — |
| TKT-M3-03 — Password/encryption + secure handling | M3 | Planned | #27 | TKT-M3-01. | — | — | — |
| TKT-M3-04 — Target conflict + destination validation | M3 | Planned | #28 | TKT-M3-01. | — | — | — |
| TKT-M3-05 — Compression progress/cancel + completion feedback | M3 | Planned | #29 | TKT-M3-01, TKT-M2-08. | — | — | — |
| TKT-M3-06 — Advanced options (multi-volume, method, threads) | M3 | Planned | #30 | TKT-M3-01. | — | — | — |
| TKT-M3-07 — Round-trip integration tests | M3 | Planned | #31 | TKT-M3-01…05. | — | — | — |
| TKT-M3-08 — Advanced compression options (full parameter set) | M3 | Planned | #61 | TKT-M3-01, TKT-M3-03. | — | — | — |
| TKT-M4-01 — Copy / Move / Duplicate core engine | M4 | Planned | #32 | TKT-M1-01, TKT-M1-06, TKT-M2-08 (TaskCenter). | — | — | — |
| TKT-M4-02 — Conflict resolution engine + batch UI | M4 | Planned | #33 | TKT-M4-01. | — | — | — |
| TKT-M4-03 — Drag-and-drop for real files (in/out) | M4 | Planned | #34 | TKT-M4-01, TKT-M1-08. | — | — | — |
| TKT-M4-04 — Favourites management | M4 | Planned | #35 | TKT-M1-01. | — | — | — |
| TKT-M4-05 — Dual-pane mode (F9-style) | M4 | Planned | #36 | TKT-M1-01, TKT-M4-01. | — | — | — |
| TKT-M4-06 — Metadata, permissions & symlink handling | M4 | Planned | #37 | TKT-M4-01. | — | — | — |
| TKT-M4-07 — Operation progress / cancel / completion feedback | M4 | Planned | #38 | TKT-M4-01, TKT-M2-08. | — | — | — |
| TKT-M4-08 — File-operation integration tests | M4 | Planned | #39 | TKT-M4-01…07. | — | — | — |
| TKT-M2-12 — Drag-out-to-Finder extraction (deferred enhancement) | M4 | Planned | #23 | TKT-M2-04, TKT-M2-06, TKT-M2-07. | — | — | — |
| TKT-M5-01 — Archive file associations + Open With + document open | M5 | Planned | #40 | TKT-M2-05. | — | — | — |
| TKT-M5-02 — Settings window (activation, limits, defaults) | M5 | Planned | #41 | TKT-M2-13. | — | — | — |
| TKT-M5-03 — Quick Look preview for archive entries | M5 | Planned | #42 | TKT-M2-07. | — | — | — |
| TKT-M5-04 — Completion notifications | M5 | Planned | #43 | TKT-M2-08. | — | — | — |
| TKT-M5-05 — About + Licenses screen | M5 | Planned | #44 | TKT-M2-01. | — | — | — |
| TKT-M5-06 — Finder Services / context actions | M5 | Planned | #45 | TKT-M2-07, TKT-M3-01. | — | — | — |
| TKT-M5-07 — Window restoration + deep links | M5 | Planned | #46 | TKT-M5-01. | — | — | — |
| TKT-M5-08 — Integration tests + manual acceptance checklist | M5 | Planned | #47 | TKT-M5-01…07. | — | — | — |
| TKT-M6-01 — Large-directory & large-archive performance/memory tuning | M6 | Planned | #48 | TKT-M1-02, TKT-M2-03. | — | — | — |
| TKT-M6-02 — Malicious-archive security test suite (CI) | M6 | Planned | #49 | TKT-M2-06, TKT-M2-07, TKT-M2-11. | — | — | — |
| TKT-M6-03 — Universal Binary (arm64 + x86_64) | M6 | Planned | #50 | TKT-M2-01. | — | — | — |
| TKT-M6-04 — Developer ID signing + notarization (`release.yml`) | M6 | Planned | #51 | TKT-M2-01, TKT-M6-03. | — | — | External: Apple Developer credentials unconfirmed |
| TKT-M6-05 — DMG packaging + GitHub Release automation | M6 | Planned | #52 | TKT-M6-04. | — | — | External: Apple Developer credentials unconfirmed |
| TKT-M6-06 — XCUITest suite expansion | M6 | Planned | #53 | TKT-M1-10, TKT-M2-05, TKT-M3-02. | — | — | — |
| TKT-M6-07 — Release docs, changelog & third-party notices | M6 | Planned | #54 | TKT-M2-01, TKT-M5-05. | — | — | — |
| TKT-M6-08 — Reproducibility & tool-version pinning audit | M6 | Planned | #55 | TKT-M1-10. | — | — | — |

## Change log
- 2026-11-23: Ledger created; planning corrections applied (authority policy, ADR-009 26.06 pinned+verified, ADR-008/SPEC-SEC extraction safety, 7zz password transport, drag-out deferred to M4, cancellation dependency, perf-vs-correctness gates).
- 2026-11-23: **TKT-M1-01 implemented & verified** on `integration/m1-m6` (commit 17ce2a0, PR #62); CI run 45130961718 green (25 tests, build+release). Host-free test-target migration tracked in TKT-M1-09.
- 2026-11-23: **TKT-M1-06** (FileOperationsService + typed FileError) and **TKT-M1-03/M1-04** (BrowserStore navigation/history/sort/selection tests) implemented & verified (commit e19fdfc); CI run 45131436860 green (37 tests).
- 2026-11-23: **TKT-M1-07** (LoadState: loading/empty/failed + Retry) and **TKT-M1-11** (persisted column widths) implemented & verified (commit fbba2bc); CI run 45131858152 green (37 tests).
- 2026-11-23: **TKT-M1-05** (New Folder/Rename/Move-to-Trash UI via NSAlert + FileOperationsService; menu ⌘⇧N/⌘R/⌘⌫; toolbar trash enabled) and **TKT-M1-02** (IconCache + 10k sort benchmark) implemented & verified (commit cbd98c1); CI run 45132417806 green (38 tests).
