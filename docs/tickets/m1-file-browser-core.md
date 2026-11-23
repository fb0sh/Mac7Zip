# M1 — File Browser Core (MVP) — Tickets

**Milestone:** M1 · **Spec:** [SPEC-FM](../specs/file-manager.md) · **Status:** Planned

> **中文摘要**：M1 工单——基础重构（Provider/Store/Access）、文件列表性能、导航/历史、选择/排序、新建/重命名/删除、文件操作服务、加载与权限状态、快捷键/右键菜单、测试与 CI 加固。

---

## TKT-M1-01 — Foundation refactor: FileSystemProvider + BrowserStore + FileAccess

- **Milestone:** M1 · **Priority:** P0 · **Type:** Refactor · **Status:** Planned
- **Background:** Phase 0 `FileBrowserModel` is a monolith; no provider seam; tests are app-hosted.
- **Scope:** Introduce `FileEntry`, `BrowserLocation`, `FileSystemProvider`, `RealFileSystemProvider`, `FileAccess`, and `BrowserStore` (replacing `FileBrowserModel`). Keep Phase 0 behavior. Convert tests to a host-free core test target.
- **Implementation Notes:** Preserve current UI bindings; wrap `FileManager` in `RealFileAccess`; keep `ObservableObject`. No new features here. Update `project.yml` for a host-free `Mac7ZipCoreTests`.
- **Dependencies:** None.
- **Acceptance Criteria:** App builds; existing 19 tests pass (moved host-free); no direct `FileManager` in UI/State; `BrowserLocation.real` conversion tested.
- **Tests:** Provider contract tests; store navigation unit tests.
- **DoD:** PR merged; CI green; behavior identical in manual smoke.
- **Related:** SPEC-FM, SPEC-SEC · ADR-003, ADR-006, ADR-007

## TKT-M1-02 — File-list performance: snapshot, icon cache, benchmark

- **Milestone:** M1 · **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Background:** Per-row `NSWorkspace` icon calls and full reloads cost time.
- **Scope:** Snapshot data source, identity-based reload, `IconCache`, and a benchmark harness for 10k entries.
- **Implementation Notes:** Cache icons by (isDirectory, extension); expose `[FileEntry]` snapshots from store; measure time-to-first-render.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** 10k load+render < 500 ms; re-sort < 100 ms; no per-row icon calls.
- **Tests:** Performance harness; icon cache unit tests.
- **DoD:** Benchmarks recorded in CI artifact/log.
- **Related:** SPEC-FM · ADR-002

## TKT-M1-03 — Navigation & history on BrowserLocation

- **Milestone:** M1 · **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Breadcrumb, typed-path entry, Back/Forward/Up operating over `BrowserLocation`.
- **Implementation Notes:** Path entry expands `~`, validates dir, sets `.real`. History is a `[BrowserLocation]` + index.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** All navigation entry points update location/table/title; invalid path shows error and no navigation.
- **Tests:** History unit tests; path-entry parsing tests.
- **DoD:** CI green.
- **Related:** SPEC-FM · ADR-003

## TKT-M1-04 — Selection, sorting, status totals

- **Milestone:** M1 · **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Multi-select, sort by column/menu, status count + selected count/size.
- **Implementation Notes:** `Set<FileEntry.ID>`; deterministic sort; status formatting via `FileSizeFormatter`.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** AC-FM-3, AC-FM-4 pass.
- **Tests:** Sorting + selection state tests.
- **DoD:** CI green.
- **Related:** SPEC-FM · ADR-002, ADR-003

## TKT-M1-05 — New Folder / Rename / Delete (Trash)

- **Milestone:** M1 · **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Create folder, inline rename, move-to-Trash delete with confirmation.
- **Implementation Notes:** Use `FileOperationsService`; inline edit in name column; native alert for delete; refresh on completion; typed errors.
- **Dependencies:** TKT-M1-01, TKT-M1-06.
- **Acceptance Criteria:** AC-FM-6; delete recovers from Trash; conflicts rejected.
- **Tests:** Temp-dir integration tests for create/rename/delete.
- **DoD:** CI green; no data loss paths.
- **Related:** SPEC-FM · ADR-003, ADR-007

## TKT-M1-06 — FileOperationsService scaffold + typed errors

- **Milestone:** M1 · **Priority:** P0 · **Type:** Refactor · **Status:** Planned
- **Scope:** Async file-op service with `FileError`, conflict model, and hooks for future copy/move.
- **Implementation Notes:** Validate names; atomic where possible; return structured results; no UI deps.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** Service methods tested; errors map to `FileError`; used by M1-05.
- **Tests:** Unit tests on temp dirs.
- **DoD:** CI green.
- **Related:** SPEC-FM · ADR-003, ADR-007

## TKT-M1-07 — Load states + access-denied/TCC UX

- **Milestone:** M1 · **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** loading/empty/failed states; access-denied errors with Retry + guidance.
- **Implementation Notes:** Map permission errors in `FileAccess`; show non-blocking progress; failed state view.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** AC-FM-5 passes; no crash on denial.
- **Tests:** chmod-fixture access-denied test; state transition tests.
- **DoD:** CI green.
- **Related:** SPEC-FM, SPEC-SEC · ADR-007

## TKT-M1-08 — Keyboard shortcuts & context menus

- **Milestone:** M1 · **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Return open, arrows, ⌘↑, ⌘[/], ⌘⌫, ⌘⇧N, rename key; right-click menu (Open, Rename, Delete, New Folder, Reveal in Finder).
- **Implementation Notes:** Mirror menu commands and table key handling; disable irrelevant actions.
- **Dependencies:** TKT-M1-03, TKT-M1-04, TKT-M1-05.
- **Acceptance Criteria:** All listed shortcuts work and match menus; context menu reflects selection.
- **Tests:** UI smoke via XCUITest (basic).
- **DoD:** CI green.
- **Related:** SPEC-FM · ADR-001

## TKT-M1-09 — Tests: FS core, ops, performance

- **Milestone:** M1 · **Priority:** P0 · **Type:** Test · **Status:** Planned
- **Scope:** Unit + integration coverage for provider, sorting, path, create/rename/delete, performance harness.
- **Implementation Notes:** Temp directories per test; deterministic fixtures.
- **Dependencies:** TKT-M1-01…07.
- **Acceptance Criteria:** Coverage of all M1 requirements; tests run host-free.
- **Tests:** The tests themselves.
- **DoD:** CI green; no flaky tests.
- **Related:** SPEC-FM · ADR-010

## TKT-M1-10 — CI hardening: lint, arch/dependency check, XCUITest spike

- **Milestone:** M1 · **Priority:** P1 · **Type:** Infrastructure · **Status:** Planned
- **Scope:** Add pinned `swift-format`/SwiftLint (non-blocking), `lipo -info` arch assertion, `otool -L` audit, host-free tests; spike XCUITest smoke on `macos-26`.
- **Implementation Notes:** Pin tool versions; explicit config files; screenshot/log artifacts for UI test.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** CI reports lint results; arch check fails on wrong arch; XCUITest spike outcome documented (feasible/not).
- **Tests:** CI self-test.
- **DoD:** Workflow updated; spike findings noted in PR.
- **Related:** SPEC-REL · ADR-010

## TKT-M1-11 — Column widths adjustable & persisted

- **Milestone:** M1 · **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Background:** FR-FM-13 requires adjustable columns that are remembered; Phase 0 uses fixed widths.
- **Scope:** User-draggable column widths; persist per window; restore on relaunch; sensible defaults.
- **Implementation Notes:** Save widths on column-resize notifications; store keyed by a stable window identifier; apply on table creation.
- **Dependencies:** TKT-M1-01, TKT-M1-02.
- **Acceptance Criteria:** Dragging borders resizes columns; widths persist across relaunch and folder changes.
- **Tests:** Persistence round-trip unit test; UI smoke drag.
- **DoD:** CI green.
- **Related:** SPEC-FM (FR-FM-13) · ADR-002

## TKT-M1-12 — Accessibility pass (VoiceOver + full keyboard)

- **Milestone:** M1 · **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Background:** User story 36 and HIG require a usable, accessible browser.
- **Scope:** Accessible labels/roles for rows and controls; full keyboard reachability of toolbar/menu/context actions; sane focus order.
- **Implementation Notes:** Set accessibility labels/elements on the table rows; `.accessibilityLabel` on SwiftUI controls; verify with Accessibility Inspector.
- **Dependencies:** TKT-M1-04, TKT-M1-08.
- **Acceptance Criteria:** VoiceOver announces name/size/date per row; every action is keyboard reachable; no blocking Accessibility Inspector issues.
- **Tests:** Manual Accessibility Inspector checklist; UI smoke.
- **DoD:** CI green; checklist signed off.
- **Related:** SPEC-FM · ADR-001
