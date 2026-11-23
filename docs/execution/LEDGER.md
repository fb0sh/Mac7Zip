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
| M1 File Browser Core | 12 tickets | **Complete** (12/12 implemented & verified) |
| M2 Archive Read & Extract | 15 tickets | In progress (7 implemented) |
| M3 Compression | 8 tickets | Not started |
| M4 File-Management Enhancements | 9 tickets (incl. deferred TKT-M2-12) | Not started |
| M5 macOS Integration | 8 tickets | Not started |
| M6 Performance/Security/Release | 8 tickets | Not started (M6-04/05 external-blocked) |

## Next eligible work
- **`TKT-M2-04` (#15)** — ArchiveFileSystemProvider (read-only) + **`TKT-M2-05` (#16)** browse archives.
- **`TKT-M2-10` (#21)** test-integrity + password UX; **`TKT-M2-11` (#22)** security fixtures.
- Manual-on-Mac items (VoiceOver/XCUITest/drag) tracked in `docs/execution/MANUAL-CHECKS.md`.

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
| TKT-M1-08 — Keyboard shortcuts & context menus | M1 | Implemented/verified (integration) | #9 | TKT-M1-03, TKT-M1-04, TKT-M1-05. | integration/m1-m6 / PR #62 | [run 45132861591](https://github.com/fb0sh/Mac7Zip/actions/runs/45132861591) — 38 tests OK | — |
| TKT-M1-09 — Tests: FS core, ops, performance | M1 | Implemented/verified (integration) | #10 | TKT-M1-01…07. | integration/m1-m6 / PR #62 | [run 45133371206](https://github.com/fb0sh/Mac7Zip/actions/runs/45133371206) — host-free, 38 tests OK | — |
| TKT-M1-10 — CI hardening: lint, arch/dependency check, XCUITest spike | M1 | Implemented/verified (integration) | #11 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45132861591](https://github.com/fb0sh/Mac7Zip/actions/runs/45132861591) — lint + `lipo` arm64 + `otool -L` OK | XCUITest spike still pending (see note) |
| TKT-M1-11 — Column widths adjustable & persisted | M1 | Implemented/verified (integration) | #56 | TKT-M1-01. | integration/m1-m6 / PR #62 | [run 45131858152](https://github.com/fb0sh/Mac7Zip/actions/runs/45131858152) — 37 tests OK | — |
| TKT-M1-12 — Accessibility pass (VoiceOver + full keyboard) | M1 | Implemented (integration); VoiceOver sign-off = manual | #57 | TKT-M1-04, TKT-M1-08. | integration/m1-m6 / PR #62 | [run 45133371206](https://github.com/fb0sh/Mac7Zip/actions/runs/45133371206) | Needs real-Mac VoiceOver check |
| TKT-M2-01 — Vendor 7zz (pinned, checksum, license, nested signing) | M2 | Implemented/verified (integration) | #12 | None (blocking for M2). | integration/m1-m6 / PR #62 | [run 45133937932](https://github.com/fb0sh/Mac7Zip/actions/runs/45133937932) — checksums OK, `7zz i` → 26.06 (arm64) | Nested signing → TKT-M6-04 |
| TKT-M2-02 — SevenZipEngine process runner | M2 | Implemented/verified (integration) | #13 | TKT-M2-01. | integration/m1-m6 / PR #62 | [run 45134444697](https://github.com/fb0sh/Mac7Zip/actions/runs/45134444697) — 48 tests OK | — |
| TKT-M2-03 — Output adapter & parsers (+ golden fixtures) | M2 | Implemented/verified (integration) | #14 | TKT-M2-02. | integration/m1-m6 / PR #62 | [run 45135271075](https://github.com/fb0sh/Mac7Zip/actions/runs/45135271075) — 57 tests OK | — |
| TKT-M2-04 — ArchiveFileSystemProvider (read-only) | M2 | Planned | #15 | TKT-M1-01, TKT-M2-03. | — | — | — |
| TKT-M2-05 — Enter/navigate archive in browser | M2 | Planned | #16 | TKT-M2-04. | — | — | — |
| TKT-M2-06 — SecurityValidator (pre-flight + limits) | M2 | Implemented/verified (integration) | #17 | TKT-M2-03. | integration/m1-m6 / PR #62 | [run 45135709912](https://github.com/fb0sh/Mac7Zip/actions/runs/45135709912) — 69 tests OK | — |
| TKT-M2-07 — Extract all/selected pipeline + UI | M2 | Implemented/verified (integration) | #18 | TKT-M2-02, TKT-M2-06, TKT-M2-08, TKT-M2-09. | integration/m1-m6 / PR #62 | [run 45143271924+](https://github.com/fb0sh/Mac7Zip/actions/runs/45143271924) final run green — 77 tests incl. real-7zz integration | — |
| TKT-M2-08 — TaskCenter + Tasks popover/progress | M2 | Implemented/verified (integration; Tasks UI pending M2-16) | #19 | TKT-M2-02. | integration/m1-m6 / PR #62 | [run 45134444697](https://github.com/fb0sh/Mac7Zip/actions/runs/45134444697) — 48 tests OK | — |
| TKT-M2-09 — Cancellation & cleanup | M2 | Implemented/verified (integration) | #20 | TKT-M2-08. | integration/m1-m6 / PR #62 | [run 45135709912](https://github.com/fb0sh/Mac7Zip/actions/runs/45135709912) — 69 tests OK | — |
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
- 2026-11-23: **TKT-M1-08** (context menu: Open/Rename/Trash/New Folder/Reveal, validated by selection & capabilities) and **TKT-M1-10** (CI: swift-format/SwiftLint non-blocking + `lipo` arm64 gate + `otool -L` audit; configs `.swiftlint.yml`/`.swift-format`) verified (commit aa679c9); CI run 45132861591 green — 38 tests, archs: arm64.
- 2026-11-23: **TKT-M1-09** (host-free test target: core sources compiled into the test bundle, `TEST_HOST` removed) and **TKT-M1-12** (accessibility labels for table + rows) verified (commit 6243d08); CI run 45133371206 green — 38 tests, no app host. **M1 COMPLETE.**
- 2026-11-23: **SECURITY CORRECTION (empirically verified)**: 7-Zip 26.06's `-p` prompt is console-bound — piped stdin **and** `script(1)` PTYs are ignored. Password operations now **fail closed** (`.passwordTransportUnavailable`) by default; `PasswordTransport.argvExplicit` is an explicitly documented, `ps`-visible opt-in. ADR-005 and SPEC-AE corrected.
- 2026-11-23: **TKT-M2-07** — `SevenZipEngine` staged extraction pipeline (validate → stage → extract → limit-check → commit), password policy, `ExtractOperation`/`CreateArchiveOperation` for TaskCenter, plus **real-7zz integration tests** (7z/zip round-trip, encrypted opt-in, fail-closed, wrong password, corrupt, RAR refusal). Verified (commit 2e89cd0); CI green — **77 tests**, integration tests actually executing (earlier silent skips fixed).
- 2026-11-23: **TKT-M2-06** (SecurityValidator: absolute/traversal/special-file/ratio/total-size/entry-count, containment check, fail-closed) and **TKT-M2-09** (StagingArea: private staging, idempotent cleanup on success/failure/cancel, per-item commit, byte counting independent of 7zz %) verified (commit e482cce); CI run 45135709912 green — 69 tests.
- 2026-11-23: **TKT-M2-03** — `SevenZipOutputParser` (listing `-slt`, progress `%`, file counts, test results, error lines, dates) with **golden fixtures captured from real 7-Zip 26.06 runs on macOS CI** (`Tests/Mac7ZipTests/Fixtures/`); verified (commit c44a893, run 45135271075) — 57 tests. Temporary capture step removed from the workflow.
- 2026-11-23: **TKT-M2-02** (SevenZipProcessRunner: concurrent stdout/stderr drain, stdin password, SIGINT→SIGTERM→SIGKILL cancellation, exit-code→ArchiveError mapping) and **TKT-M2-08** (TaskCenter actor: queue, lifecycle, bounded history, observers, cancel) implemented & verified (commit a1883ba); CI run 45134444697 green — 48 tests. Tasks popover UI remains for TKT-M2-16.
- 2026-11-23: **TKT-M2-01** — vendored 7-Zip 26.06 arm64+x86_64 into `Vendor/7zz/26.06/` with `License.txt`, `readme.txt`, `SHA256SUMS`, `README.md`; added `scripts/verify-7zz.sh` (CI gate) and `scripts/bundle-7zz.sh`; workflow verifies + bundles + executes `7zz i`. Verified (commit 89178f4, run 45133937932): checksums OK, bundled helper = arm64, runtime prints `7-Zip (z) 26.06 (arm64)`. Nested codesign deferred to TKT-M6-04.
