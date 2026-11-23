# M4 — File-Management Enhancements — Tickets

**Milestone:** M4 · **Epic:** EPIC-M4 · **Spec:** [SPEC-FO](../specs/file-operations.md) · **Status:** Planned

> **中文摘要**：M4 工单——复制/移动/副本、冲突解决、真实文件拖放、收藏、双面板、元数据/符号链接、进度/取消、集成测试。全部可实施，遵循 SPEC-FO。

---

## TKT-M4-01 — Copy / Move / Duplicate core engine

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Background:** MVP has create/rename/delete only; professional file management needs copy/move/duplicate. (`TKT-M1-06` scaffolded the service.)
- **Scope:** Extend `FileOperationsService` with recursive copy, move (same-volume atomic rename / cross-volume copy+verify+delete), and duplicate (keep-both). Async, cancellable.
- **Implementation Notes:** Recursive walk via `FileAccess`; preserve metadata; verify size (and checksum for critical moves) before reporting success; never delete source until destination verified.
- **Dependencies:** TKT-M1-01, TKT-M1-06, TKT-M2-08 (TaskCenter).
- **Acceptance Criteria:** AC-FO-1; same-volume move is O(1) rename; cross-volume failure leaves source intact.
- **Tests:** Temp-dir integration tests incl. nested dirs, large files, cancel.
- **DoD:** CI green; SPEC-FO ACs pass.
- **Related:** SPEC-FO · ADR-003, ADR-007

## TKT-M4-02 — Conflict resolution engine + batch UI

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Replace / Skip / Keep Both with apply-to-all and per-item choices; batch conflict sheet.
- **Implementation Notes:** Conflict evaluated per destination; keep-both auto-suffix; policy object shared with engine.
- **Dependencies:** TKT-M4-01.
- **Acceptance Criteria:** AC-FO-2; apply-to-all honored; no silent overwrite.
- **Tests:** Conflict matrix unit tests; integration with clashing fixtures.
- **DoD:** CI green.
- **Related:** SPEC-FO · ADR-003

## TKT-M4-03 — Drag-and-drop for real files (in/out)

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Accept external Finder drops into the list; drag real files out; Option=move, default=copy; drop highlight. (Archive→Finder drag-out already delivered in `TKT-M2-12`.)
- **Implementation Notes:** `NSItemProvider`/`NSFilePromiseProvider`; resolve URLs via `FileAccess`; route through `FileOperationsService`.
- **Dependencies:** TKT-M4-01, TKT-M1-08.
- **Acceptance Criteria:** AC-FO-3; modifier semantics correct; invalid drops ignored safely.
- **Tests:** Pasteboard unit tests; manual drag checklist.
- **DoD:** CI green; manual verified.
- **Related:** SPEC-FO · ADR-003, ADR-007

## TKT-M4-04 — Favourites management

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Add/remove/reorder custom sidebar roots; persist; open via click.
- **Implementation Notes:** `FavouritesStore` with codable paths (security-scoped bookmarks reserved); sidebar section.
- **Dependencies:** TKT-M1-01.
- **Acceptance Criteria:** AC-FO-4.
- **Tests:** Persistence round-trip; reorder logic.
- **DoD:** CI green.
- **Related:** SPEC-FO · ADR-007

## TKT-M4-05 — Dual-pane mode (F9-style)

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Two independent `BrowserStore`s in a split; copy/move between panes; per-pane history/selection/status; toolbar toggle.
- **Implementation Notes:** Compose two panes; focused-pane routing; divider; independent providers (real or archive).
- **Dependencies:** TKT-M1-01, TKT-M4-01.
- **Acceptance Criteria:** AC-FO-5; panes independent; copy between works incl. archive source.
- **Tests:** Dual-pane state tests; UI smoke.
- **DoD:** CI green.
- **Related:** SPEC-FO · ADR-003

## TKT-M4-06 — Metadata, permissions & symlink handling

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Show POSIX permissions/owner; symlink indicator; preserve symlinks by default in copy/move; warn on cross-boundary links.
- **Implementation Notes:** Read resource values; don't follow links during copy by default; refusal typed error.
- **Dependencies:** TKT-M4-01.
- **Acceptance Criteria:** Permission columns render; symlink copy preserves link; escaping link refused.
- **Tests:** Symlink fixture tests.
- **DoD:** CI green.
- **Related:** SPEC-FO, SPEC-SEC · ADR-007

## TKT-M4-07 — Operation progress / cancel / completion feedback

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Route copy/move through `TaskCenter`; progress + cancel; completion toast with reveal.
- **Implementation Notes:** Reuse Tasks popover/status; clean partials per cancel policy.
- **Dependencies:** TKT-M4-01, TKT-M2-08.
- **Acceptance Criteria:** AC-FO-6; UI responsive; cleanup verified.
- **Tests:** Cancellation integration.
- **DoD:** CI green.
- **Related:** SPEC-FO, SPEC-TM · ADR-005

## TKT-M4-08 — File-operation integration tests

- **Priority:** P1 · **Type:** Test · **Status:** Planned
- **Scope:** Copy/move/duplicate, conflicts, drag (where automatable), dual-pane, cancel, symlink cases.
- **Implementation Notes:** Temp dirs; deterministic fixtures; cross-volume simulated via temp volumes where possible.
- **Dependencies:** TKT-M4-01…07.
- **Acceptance Criteria:** All SPEC-FO AC scenarios covered.
- **Tests:** The tests themselves.
- **DoD:** CI green; no flaky.
- **Related:** SPEC-FO · ADR-010

## TKT-M2-12 — Drag-out-to-Finder extraction (deferred enhancement)

- **Milestone:** M4 · **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Background:** Owner's high-frequency workflow ("open archive → drag entries out to a file manager"). Deferred from the MVP critical path by planning correction (2026-11-23) to keep MVP focused; retained in full implementation scope.
- **Scope:** Drag selected entries (or a folder subtree) from the archive browser to external Finder targets; extraction runs through the secure pipeline; drop destination honored.
- **Implementation Notes:** `NSFilePromiseProvider`/pasteboard-based drag; feed selected paths to engine extraction into the drop directory; enforce ADR-008 fail-closed; show task progress.
- **Dependencies:** TKT-M2-04, TKT-M2-06, TKT-M2-07.
- **Acceptance Criteria:** AC-AB-6 passes; unsafe entries refuse; cancellation cleans up.
- **Tests:** Integration drag-simulation where feasible; extraction-pipeline tests.
- **DoD:** CI green; manual drag on real Mac documented.
- **Related:** SPEC-AB (FR-AB-12) · ADR-006, ADR-008
