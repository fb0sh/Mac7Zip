# SPEC-FO — File Operations (M4)

**Status:** Accepted · **Milestone:** M4 · **Last updated:** 2026-11-23

> **中文摘要**：M4 文件操作规格——复制/移动/复制副本、批量冲突解决（替换/跳过/保留两者/全部应用）、真实文件拖放（进出/外部源）、收藏目录、双面板、元数据/权限显示与符号链接语义。基于 M1 的 `FileOperationsService` 与 `TaskCenter` 扩展。

## 1. Overview

Adds professional file operations on top of M1's provider/state seams: copy, move, duplicate, batch progress, conflict resolution, drag-and-drop for real files, favourites, and an optional dual-pane mode.

## 2. Goals

- Safe, cancellable copy/move of files and folders with verified results.
- Predictable conflict handling at scale (apply-to-all).
- Native drag-and-drop consistent with Finder.
- Favourites and dual-pane for power users.

## 3. Non-goals

- Archive→Finder drag-out (delivered in MVP `TKT-M2-12`).
- Permanent (non-Trash) delete; secure-erase.
- Network/SMB-specific throughput tuning.
- Cloud-file provider semantics beyond defaults.

## 4. User Scenarios

- **S1**: Copy a folder to another directory; progress shows; cancel cleans partials per policy.
- **S2**: Move a file within same volume (fast) vs across volumes (copy+verify+delete).
- **S3**: Copy into a folder with name clashes → choose replace/skip/keep-both, apply to all.
- **S4**: Drag files from Finder into the list → copied in; Option-drag to move.
- **S5**: Add/reorder favourites; persist across launches.
- **S6**: Enable dual-pane; copy between panes.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-FO-01 | Copy files/folders (recursive) with progress; verify sizes before reporting success. |
| FR-FO-02 | Move: same-volume atomic rename; cross-volume copy+verify+delete; never lose source on failure. |
| FR-FO-03 | Duplicate ("Keep Both") with auto-suffix. |
| FR-FO-04 | Batch conflict resolution: replace / skip / keep-both, with apply-to-all and per-item. |
| FR-FO-05 | Drag-and-drop real files: accept external drops; in-app drag out; Option=move, default=copy; show drop highlight. |
| FR-FO-06 | Favourites: add/remove/reorder custom sidebar roots; persist. |
| FR-FO-07 | Dual-pane: two independent `BrowserStore`s; copy/move between panes; each pane own history/selection/status. |
| FR-FO-08 | Show POSIX permissions/owner and symlink indicator; resolve symlink policy (preserve links by default). |
| FR-FO-09 | All long operations run via `TaskCenter` with progress/cancel; completion feedback. |
| FR-FO-10 | Permission/access errors are typed and actionable; partial results reported. |

## 6. UX / Interaction Design

- Conflicts: batch sheet listing items with a per-item choice + "apply to all" master; destructive replace styled.
- Drag: source highlight, cursor badge (+ copy / arrow move), spring-loaded folders.
- Dual-pane: toolbar toggle; draggable divider; each pane status bar.
- Favourites: sidebar "Favourites" section, drag to reorder, context menu to remove.

## 7. Technical Design

- Extend `FileOperationsService` with `copy`, `move`, `duplicate`, batch plans; wrap in `TaskCenter` operations.
- `CopyEngine` handles same-volume rename fast path and cross-volume streaming; verifies checksums/size for critical moves.
- `DragDropProvider` builds `NSItemProvider`/`NSFilePromiseProvider`; external drops resolved via `FileAccess`.
- `FavouritesStore` persists `[URL]` bookmarks (security-scoped bookmarks reserved for future sandbox) in `UserDefaults`/JSON.
- `DualPaneStore` composes two `BrowserStore`s; shared toolbar routes to the focused pane.

## 8. Data Models / Interfaces

```swift
enum FileOperationKind: Sendable { case copy, move, duplicate }
struct FileOperationPlan: Sendable { var kind: FileOperationKind; var sources: [URL]; var destination: URL; var conflictPolicy: ConflictPolicy }
enum ConflictPolicy: Sendable { case ask, replace, skip, keepBoth }
struct Favourite: Identifiable, Codable, Sendable { let id: UUID; var name: String; var path: String }
```

## 9. Error Handling

- Typed `FileError` (accessDenied/notFound/alreadyExists/diskFull/operationFailed/cancelled).
- Partial batch results summarized (succeeded/failed/skipped lists).
- Move across volumes: failure mid-way leaves source intact and reports partial destination cleanup.

## 10. Performance Requirements

- Copy throughput near disk-bound; progress ≥ 2/s.
- 10,000-file copy remains responsive; memory bounded (stream, no full buffering).
- Dual-pane listing independent; no cross-pane coupling.

## 11. Security Requirements

- Never overwrite without an explicit conflict policy.
- Preserve symlinks by default; refuse operations that would escape into unexpected locations via links.
- Respect TCC/permissions; no privilege escalation.
- Temp/partial files cleaned on cancel/failure.

## 12. Acceptance Criteria

- **AC-FO-1** — Given 100 files copied, Then all exist with identical contents and operation reports success.
- **AC-FO-2** — Given name clash, When choosing skip with apply-to-all, Then no clashing files overwritten.
- **AC-FO-3** — Given external drag of 3 files, Then they are copied into the directory.
- **AC-FO-4** — Given a favourite added, Then it persists across relaunch.
- **AC-FO-5** — Given dual-pane, Then copying from pane A to B works and each pane keeps its own selection.
- **AC-FO-6** — Given cancel mid-copy, Then partials are cleaned per policy and state is `cancelled`.

## 13. Test Strategy

- Integration on temp dirs: copy/move/duplicate, conflicts, cancel, cross-volume simulation.
- Drag via pasteboard unit tests where possible; manual drag checklist on real Mac.
- Dual-pane state tests.

## 14. Dependencies

- M1 `FileOperationsService`/`BrowserStore`; M2 `TaskCenter`; ADR-003/007.

## 15. Related ADRs / Tickets

- ADRs: ADR-003, ADR-007
- Tickets: `TKT-M4-01` … `TKT-M4-08`
