# ADR-003 — File-Manager State Model and Navigation Architecture

**Status:** Accepted · **Date:** 2026-11-23 · **Deciders:** Architecture

> **中文摘要**：把 Phase 0 的 `FileBrowserModel` 单块拆分为每窗口一个 `BrowserStore`（位置、历史、选择、排序）加独立服务（文件操作、提供者）；用 `BrowserLocation` 枚举区分真实路径与压缩包内路径，避免语义混淆。

## Context

Phase 0's `FileBrowserModel` (153 LOC, `@MainActor ObservableObject`) conflates: current directory, history stack, selection, sort, directory loading, and "open" behavior. Phase 1 adds rename/delete/new-folder; Phase 2 adds archive locations where the "current path" is an entry *inside* an archive, not a real filesystem URL. A single mutable `URL` cannot safely represent both.

## Decision Drivers

- Need multiple windows later, each with independent navigation/selection.
- Archive browsing must not accidentally pass archive-internal paths to `FileManager`.
- Commands (menus/toolbar/shortcuts) need a single observable source of truth.
- Refactor must preserve existing Phase 0 behavior with regression tests (user's Q7).

## Considered Options

1. **Keep one monolithic model** and add archive fields: fastest now, but conflates semantics and blocks multi-window/testing.
2. **Split into focused stores + services with an explicit location type (chosen)**.
3. Full Redux/TCA-style unidirectional store: overkill; adds dependency and ceremony.

## Decision

- Introduce **`BrowserStore`** (`@MainActor`, per window; keep `ObservableObject`/`@Published` in M1 for proven behavior): owns `location`, `history`, `selection`, `sort`, `loadState` (`.empty/.loading/.loaded/.failed`).
- Introduce **`BrowserLocation`**:
  ```swift
  enum BrowserLocation: Hashable, Sendable {
      case real(URL)                              // a real filesystem directory
      case archive(archiveURL: URL, internalPath: String)  // entry inside an archive
  }
  ```
  Only the real-file `FileSystemProvider` may convert `.real` to `URL`; archive paths are opaque to `FileManager`.
- Split responsibilities into **`FileOperationsService`** (rename/delete/new-folder; later copy/move) and **`FileSystemProvider`** (ADR-006). `BrowserStore` orchestrates, never touches disk directly.
- History is a `BrowserLocation` stack with back/forward; selection is `Set<FileEntry.ID>` scoped to the current location and cleared on navigation.
- Open behavior: `.real` directory → navigate; `.real` file → `NSWorkspace.open`; `.archive` directory → navigate into; `.archive` file → extract-to-temp preview (later milestone).

## Rationale

Separating location semantics prevents a whole class of bugs (archive path mistaken for disk path) and gives each window an isolated store. Keeping `ObservableObject` in M1 preserves Phase 0 behavior and reduces refactor risk; `@Observable` can be adopted later behind the same API.

## Consequences

- Phase 0 `FileBrowserModel` is replaced; existing 19 tests remain and new store tests are added.
- All navigation entry points must build a `BrowserLocation`, not a bare `URL`.
- Enables multi-window and archive browsing without further structural change.

## Risks / Trade-offs

- Refactor churn in M1; mitigated by delivering it as `TKT-M1-01` with regression tests before feature work.
- `BrowserLocation` may need a `.virtual` variant later (e.g., memory archives); the enum extends without breaking callers.

## Related

- Specs: `SPEC-FM`
- ADRs: ADR-006
- Tickets: `TKT-M1-01`, `TKT-M1-03`, `TKT-M1-04`
