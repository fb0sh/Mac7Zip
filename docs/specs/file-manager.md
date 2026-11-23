# SPEC-FM — File Manager

**Status:** Accepted (M1) · **Milestones:** M1 (MVP core), M4 (advanced file ops) · **Last updated:** 2026-11-23

> **中文摘要**：文件管理器规格——浏览真实目录、导航/历史、排序/多选、状态栏、新建/重命名/删除、加载/空/错误状态与性能指标。复制/移动/拖放/收藏/双面板属于 M4 非目标。

## 1. Overview

The file manager is the primary surface. M1 delivers a polished single-pane browser over the real filesystem with navigation, sorting, multi-selection, status, and basic destructive operations (new folder, rename, delete). It sits on a `FileSystemProvider` abstraction so M2 can reuse the same UI for archive contents.

## 2. Goals

- Browse any accessible real directory, including the user's Home, quickly and safely.
- Precise keyboard + mouse navigation and multi-select.
- Clear, low-noise status and error feedback.
- Structure that generalizes to archive browsing without violating path semantics.

## 3. Non-goals (M1)

- Copy, move, duplicate, drag-and-drop, favourites, dual-pane, tabs (M4 — see SPEC-FO).
- Archive browsing (M2), compression (M3).
- Search / filter, tags, extended metadata editing.
- Network volumes/SMB optimizations beyond default behavior.

## 4. User Scenarios

- **S1**: Launch app → lands in Home → sees real files with icons, sizes, dates.
- **S2**: Click a folder → enters; click breadcrumb/Back → returns.
- **S3**: Type a path → navigates; invalid path → clear error, stays put.
- **S4**: Sort by Size desc, multi-select 3 files → status shows count and total size.
- **S5**: New Folder / Rename / Delete with confirmation; access denied → actionable alert.
- **S6**: Open a directory the user lacks permission to read → failed state with Retry / reveal in Finder.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-FM-01 | List entries of the current real directory via `RealFileSystemProvider`; show Name, Size, Kind, Date Modified. |
| FR-FM-02 | `BrowserLocation.real(URL)` is the only representation of a real path; never mix with archive paths. |
| FR-FM-03 | Navigate by double-click (dir), breadcrumb click, Back/Forward, Enclosing Folder, and typed path (`~` expansion). |
| FR-FM-04 | History stack supports Back/Forward; disabled at bounds. |
| FR-FM-05 | Sort by Name/Size/Kind/Date asc/desc via header click and View menu; folders/files sorted deterministically (name tie-break). |
| FR-FM-06 | Multi-select (click, ⌘-click, ⇧-click, ⌘A); selection cleared on navigation. |
| FR-FM-07 | Status bar: total item count; when selection non-empty, selected count + total selected size. |
| FR-FM-08 | New Folder: create in current dir; inline name prompt; conflict → error. |
| FR-FM-09 | Rename: inline edit; validate empty/duplicate; preserve extension warning. |
| FR-FM-10 | Delete: move to Trash by default with confirmation; report failures; refresh. |
| FR-FM-11 | Loading state during reads; empty state; failed state with error text + Retry. |
| FR-FM-12 | Open file → default app via `NSWorkspace`; open dir → navigate. |
| FR-FM-13 | Column widths adjustable and persisted per window. |
| FR-FM-14 | Keyboard: ↑/↓ selection, Return open, ⌘↑ enclosing, ⌘[ / ⌘] history, ⌘⌫ delete, Return-edit (F2-like rename), ⌘⇧N new folder. |
| FR-FM-15 | Activating an archive file (double-click/Return) follows the "archive activation" preference: Open/browse (default) or Extract to `<archiveName>/`. |

## 6. UX / Interaction Design

- **Layout**: Sidebar (favourites) → Detail (`PathBar` / `FileListView` / `StatusBar`). Native toolbar and menus (Phase 0 preserved).
- **States**: `loading` shows a small progress in status bar (no blocking spinner); `empty` shows a centered placeholder; `failed` shows icon + message + "Retry" + "Reveal in Finder".
- **Selection**: alternating rows, standard accent highlight; status reflects selection live.
- **Rename**: inline text field in the name column; Enter commits, Esc cancels, invalid name shows inline red hint.
- **Delete**: native `NSAlert` confirmation summarizing count; destructive button style.
- **Accessibility**: every toolbar/button has `.help`; rows expose name/size/date to accessibility; full keyboard reachability.

## 7. Technical Design

- `BrowserStore` (`@MainActor`) holds `location: BrowserLocation`, `history`, `selection: Set<FileEntry.ID>`, `sort`, `loadState`, `items: [FileEntry]`.
- `RealFileSystemProvider` implements `FileSystemProvider` over `FileAccess` (ADR-007), reading resource keys off-main via `Task.detached`.
- `FileListView` (AppKit) consumes snapshots and emits selection/open intents; icon caching in `IconCache` (ADR-002).
- File ops via `FileOperationsService` (async, typed errors) — M1 implements create/rename/trash-delete only.
- Path entry parses `~`, validates existence, normalizes to a directory (file → parent).

## 8. Data Models / Interfaces

```swift
enum BrowserLocation: Hashable, Sendable { case real(URL); case archive(archiveURL: URL, internalPath: String) }

enum LoadState: Equatable { case empty, loading, loaded, failed(FileError) }

struct FileEntry: Identifiable, Hashable, Sendable {
    let id: EntryID; let name: String; let isDirectory: Bool
    let size: Int64; let modificationDate: Date?; let kind: String
}

enum FileError: Error, Equatable {
    case accessDenied(String); case notFound(String); case alreadyExists(String)
    case invalidName(String); case operationFailed(String); case cancelled
}
```

## 9. Error Handling

- Map `NSFileReadNoPermissionError`/`EACCES`/`EPERM` → `.accessDenied(path)`.
- Not-found on navigation → `.notFound`, keep prior location.
- Rename/create conflicts → `.alreadyExists`, inline message.
- All destructive ops are atomic-or-reported; never claim success without verifying the result.

## 10. Performance Requirements

- Load 10,000-entry directory and render first screen **< 500 ms** (CI baseline arm64 reference machine, measured by `TKT-M1-02` harness).
- Re-sort 10,000 in-memory entries **< 100 ms**.
- Idle memory for 10,000 entries **< 100 MB** additional.
- No `NSWorkspace` icon calls per row per reload (icon cache required).

## 11. Security Requirements

- All access via `FileAccess` (ADR-007); never bypass TCC.
- Delete uses Trash (recoverable) by default; permanent delete is out of scope for M1.
- No path is constructed from unvalidated user input without normalization.

## 12. Acceptance Criteria

- **AC-FM-1** — Given a readable Home directory, When the app launches, Then the table shows real entries with correct Name/Size/Kind/Date and a status count.
- **AC-FM-2** — Given the browser at Home, When the user double-clicks a subfolder, Then the table lists that folder and the path bar updates.
- **AC-FM-3** — Given any list, When the user clicks the "Size" header twice, Then rows sort ascending then descending and the indicator matches.
- **AC-FM-4** — Given 3 selected files, When selection changes, Then the status bar shows "3 selected — <size>".
- **AC-FM-5** — Given a directory without read permission, When the user navigates to it, Then a failed state with an actionable message appears and the app does not crash.
- **AC-FM-6** — Given an existing file, When the user renames it to an existing name, Then the rename is rejected with an inline error and the file is unchanged.
- **AC-FM-7** — Given a 10,000-entry directory fixture, When loaded, Then first render meets the performance budget.

## 13. Test Strategy

- Unit: sorting, path utilities, `BrowserLocation` conversions, error mapping, `FileOperationsService` on temp dirs.
- Integration: rename/delete/new-folder against a temp sandbox directory; access-denied via chmod 000 fixture.
- Performance: `TKT-M1-02` benchmark harness (10k synthetic entries).
- UI smoke (XCUITest): launch, navigate, sort, select (SPEC-REL).

## 14. Dependencies

- `FileAccess`/`RealFileSystemProvider` (ADR-007/006), `TaskCenter` not required for M1 core.
- CI arch + test harness (ADR-010).

## 15. Related ADRs / Tickets

- ADRs: ADR-001, ADR-002, ADR-003, ADR-006, ADR-007
- Tickets: `TKT-M1-01` … `TKT-M1-12`; M2: `TKT-M2-13`; M4: `EPIC-M4`
