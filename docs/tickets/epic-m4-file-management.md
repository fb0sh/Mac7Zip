# EPIC-M4 — File-Management Enhancements

**Milestone:** M4 · **Priority:** P1 · **Status:** Planned · **Spec:** [SPEC-FM](../specs/file-manager.md)

> **中文摘要**：M4 Epic——在 MVP 之后补全专业文件管理：复制/移动、拖放、收藏、双面板、冲突解决 UI 与权限细节。以端到端可验证切片拆分。

## Objective

Deliver the professional file-management capabilities deferred from the MVP: copy, move, drag-and-drop, favourites, and optional dual-pane — built on the `FileOperationsService` and `FileSystemProvider` seams from M1.

## Scope & Ticket breakdown (epic-level)

| ID | Title | Pri | Notes |
|---|---|---|---|
| TKT-M4-01 | Copy / Move engine + progress | P1 | Batch async copy/move with conflict handling; reuse `TaskCenter`. |
| TKT-M4-02 | Conflict resolution UI (replace/skip/keep both, apply-to-all) | P1 | Batch dialog with per-item + apply-all. |
| TKT-M4-03 | Drag-and-drop into/out of the file list | P1 | `NSFilePromise`/pasteboard; accept external drops; move vs copy via modifier. |
| TKT-M4-04 | Favourites management | P2 | Add/reorder/remove custom sidebar roots; persist in `UserDefaults`. |
| TKT-M4-05 | Dual-pane mode (7-Zip F9-style) | P2 | Two `BrowserStore`s in a split; independent history/selection; copy between panes. |
| TKT-M4-06 | Extended metadata & permission display | P2 | Show POSIX perms/owner; symbolic link indicator. |
| TKT-M4-07 | File-manager tests (copy/move/conflict/drag) | P1 | Integration on temp dirs. |

## Acceptance Criteria (epic-level)

- **AC-M4-1** — Given a folder of N files, When copied to another folder, Then all appear with identical contents and progress reported; cancellation leaves no partial inconsistency beyond documented behavior.
- **AC-M4-2** — Given an existing destination file, When copying, Then conflict UI offers replace/skip/keep-both and apply-to-all works.
- **AC-M4-3** — Given external files dragged onto the list, Then they are copied into the directory and the list refreshes.
- **AC-M4-4** — Given a favourite added, Then it appears in the sidebar and persists across launches.
- **AC-M4-5** — Given dual-pane enabled, Then each pane navigates independently and a "copy to other pane" action works.

## Dependencies

- M1 complete (`FileOperationsService`, `BrowserStore`, provider seam).
- M2 `TaskCenter` for long copy/move operations.
- ADR-003, ADR-007.

## Risks

- Copy/move on network volumes and permission edge cases; mitigate with typed errors and tests.
- Dual-pane state complexity; keep as P2 and behind capability checks.
