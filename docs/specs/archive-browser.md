# SPEC-AB — Archive Browser

**Status:** Accepted · **Milestones:** M2 (read-only, MVP), M5 (integration) · **Last updated:** 2026-11-23

> **中文摘要**：压缩包内部浏览规格——通过只读 `ArchiveFileSystemProvider` 进入并逐层浏览 7z/ZIP 等压缩包，路径栏显示“压缩包 + 内部路径”，可选中并解压条目；MVP 不支持在包内写/删/改名，也不支持包内搜索。

## 1. Overview

M2 makes the same file browser able to open and navigate the inside of an archive read-only, reusing `FileSystemProvider` and `BrowserLocation`. This is the bridge between file management and archive operations.

## 2. Goals

- Enter an archive from the file list and browse its folder tree.
- Show correct Name/Size/Date/kind for entries; directories navigable.
- Extract selected entries (and extract-all) from within the browser.
- Keep real-path vs archive-path semantics impossible to confuse.

## 3. Non-goals (M2)

- Editing/renaming/deleting inside an archive (archives are read-only here).
- Nested archive traversal (archive-in-archive) — later.
- In-archive search / quick preview (M5).
- Solid-archive random access optimizations beyond 7zz defaults.

## 4. User Scenarios

- **S1**: Double-click `photos.zip` → browser enters archive root, lists entries.
- **S2**: Enter an internal folder, use breadcrumb/Back to move.
- **S3**: Multi-select entries → "Extract" extracts only those.
- **S4**: Click "Enclosing Folder" at archive root → returns to the real folder containing the archive.
- **S5**: Open an encrypted archive → password prompt before listing/extracting.
- **S6**: Drag selected entries (or a folder) from the archive to Finder → they are extracted to the drop location.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-AB-01 | `ArchiveFileSystemProvider` implements `FileSystemProvider` with `capabilities = [.list]`. |
| FR-AB-02 | Entering an archive produces `BrowserLocation.archive(archiveURL:internalPath:"")`. |
| FR-AB-03 | Internal navigation updates `internalPath`; breadcrumb shows archive name then internal segments. |
| FR-AB-04 | Directory entries are navigable; file entries are selectable and extractable. |
| FR-AB-05 | Path bar and Back/Forward operate over archive locations; Enclosing Folder at root exits to real parent of archive file. |
| FR-AB-06 | Extract Selected / Extract All available from toolbar/context menu; disabled when no selection. |
| FR-AB-07 | Encrypted archives prompt for password before listing (or listing shows encrypted flag and prompts on extract). |
| FR-AB-08 | File actions that mutate (rename/delete/new folder/copy-in) are disabled in archive locations. |
| FR-AB-09 | Entries never expose a real `URL`; the archive's own real URL is held separately. |
| FR-AB-10 | Show archive-specific columns when the engine provides them: Packed Size, CRC, Encrypted flag, Method, and Folder/File counts; hide these for real-file locations. |
| FR-AB-11 | Offer "Extract here" and "Extract to `<archiveName>/`" convenience targets, matching the 7-Zip operation model. |
| FR-AB-12 | Support **drag-out-to-extract**: dragging one or more selected entries (or a folder subtree) from the archive browser to Finder extracts them to the drop destination. Deferred to **M4** as a first-class enhancement (retained in full scope; not on the MVP critical path). |
| FR-AB-13 | When the archive activation preference is "Extract", double-clicking an archive in the file list extracts it to `<archiveName>/` instead of entering it (default remains "Open"). |

## 6. UX / Interaction Design

- **Breadcrumb**: `[ArchiveName.zip] ▸ folder ▸ subfolder` with a distinct icon for the archive root; the leading archive chip returns to archive root; clicking the real-volume area exits.
- **Visual affordance**: entering an archive shows a subtle "read-only archive" badge in the status bar.
- **Empty archive**: placeholder "This archive is empty".
- **Corrupt on open**: failed state with diagnostic + "Open with system default" fallback.
- **Selection/extract**: standard multi-select; Extract action mirrors real-file extract.

## 7. Technical Design

- `ArchiveFileSystemProvider` holds a per-archive **listing cache** built from one `ArchiveEngine.listContents` call; navigation filters the cached entries by `internalPath` prefix to synthesize directory listings (no repeated 7zz calls for directory navigation).
- On entering, call list once; on refresh, invalidate cache.
- `BrowserStore` uses `capabilities` to disable mutating commands.
- Password provided to engine for listing/extraction; cached only in memory for the session per archive.

## 8. Data Models / Interfaces

```swift
struct ArchiveListing { let entries: [ArchiveEntry]; let fetchedAt: Date }

// entry paths are POSIX-style relative paths inside the archive, e.g. "folder/file.txt"
func directoryListing(prefix: String) -> [FileEntry]
```

## 9. Error Handling

- Encrypted → `.passwordRequired`; wrong password → `.wrongPassword`, allow retry.
- Corrupt → failed state with excerpt.
- Unsafe entries are fine to *list*; only extraction triggers `.unsafeEntry`.

## 10. Performance Requirements

- Enter a 100k-entry archive and render archive root **< 3.5 s** (bounded by engine list).
- Directory navigation within a loaded archive **< 50 ms** (in-memory filtering only).
- Cache memory bounded; evict on leaving archive or after N archives.

## 11. Security Requirements

- Read-only guarantees: no mutating command is wired for archive locations.
- Extraction from browser obeys ADR-008 fail-closed.
- Archive internal paths never passed to `FileManager`/`NSWorkspace` as real paths.

## 12. Acceptance Criteria

- **AC-AB-1** — Given a `.zip`, When double-clicked in the browser, Then its root entries render with a read-only indicator.
- **AC-AB-2** — Given an internal folder, When entered, Then only that folder's children show and the breadcrumb reflects the path.
- **AC-AB-3** — Given archive root, When "Enclosing Folder" is used, Then the browser returns to the real directory containing the archive.
- **AC-AB-4** — Given 2 selected entries in an archive, When "Extract Selected", Then exactly those are extracted.
- **AC-AB-5** — Given an archive location, Then Rename/Delete/New Folder are disabled.
- **AC-AB-6** — Given 2 selected entries, When dragged to Finder (M4), Then both are extracted to the drop destination and the source archive is unchanged.
- **AC-AB-7** — Given the activation preference is "Extract", When an archive is double-clicked in the file list, Then it extracts to `<archiveName>/` and does not enter browse mode.

## 13. Test Strategy

- Unit: directory filtering/prefix logic; path semantics (archive path never becomes URL).
- Integration: enter real fixture archives; verify listings vs 7zz ground truth; extract-selected.
- UI smoke: enter archive, navigate, extract selected.

## 14. Dependencies

- SPEC-AE engine listing/extraction; ADR-006 provider; ADR-003 location.

## 15. Related ADRs / Tickets

- ADRs: ADR-006, ADR-003, ADR-004
- Tickets: `TKT-M2-04`, `TKT-M2-05`, `TKT-M2-07`, `TKT-M2-12`, `TKT-M2-13`, `TKT-M2-14`, `TKT-M2-15`; M5: `EPIC-M5`
