# SPEC-CW — Compression Workflow

**Status:** Accepted · **Milestone:** M3 (MVP) · **Last updated:** 2026-11-23

> **中文摘要**：压缩流程规格——通过原生 SwiftUI 表单创建 ZIP/7z，支持等级/方法/密码加密，处理目标冲突，显示进度并可取消，完成后反馈。MVP 仅创建 ZIP/7z，TAR/GZIP 等后续。

## 1. Overview

M3 lets users create archives from selected files/folders (or the current directory). It provides a native SwiftUI form, drives `SevenZipEngine.createArchive` through `TaskCenter`, handles conflicts and progress, and reports completion.

## 2. Goals

- Create ZIP and 7z archives with sensible defaults and optional encryption.
- Native macOS form; advanced options collapsed by default.
- Safe target handling (no accidental overwrite), cancellable, clear feedback.

## 3. Non-goals (MVP)

- TAR/GZIP/BZIP2/XZ/WIM creation (P2).
- Multi-volume archives (P2), solid-block tuning, custom filters (P2).
- RAR creation (unsupported).
- Differential/incremental update of existing archives (P2).

## 4. User Scenarios

- **S1**: Select files → "Add to Archive" → choose name/format/level → Create → progress → success reveal.
- **S2**: Choose existing destination → conflict dialog (Replace/Keep Both/Cancel).
- **S3**: Enable password → 7z AES-256; weak password warning.
- **S4**: Cancel mid-create → partial temp removed, no corrupt destination.
- **S5**: Invalid name/destination not writable → inline validation, Create disabled.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-CW-01 | "Add to Archive" available for a non-empty selection and for "current folder" via menu. |
| FR-CW-02 | Form fields: name, location (NSSavePanel), format (7z/ZIP), compression level (0–9/Store…Ultra), optional password. |
| FR-CW-03 | Advanced section (collapsed): method (7z: LZMA2 default), encryption method (AES-256 for 7z), thread count (later). |
| FR-CW-04 | Validate name/non-empty/location-writable before enabling Create. |
| FR-CW-05 | Target conflict → Replace / Keep Both / Cancel; Keep Both auto-suffix. |
| FR-CW-06 | Create runs via `TaskCenter`; progress 0–100% or indeterminate; Cancel available. |
| FR-CW-07 | On success: reveal archive in Finder option + non-blocking confirmation; on failure: actionable error. |
| FR-CW-08 | Password never logged; not persisted beyond the operation unless user opts in (out of scope). |
| FR-CW-09 | Cancel cleans temp; no partial final archive left; if replacing, original preserved until success. |
| FR-CW-10 | Provide a collapsed **Advanced** section (deferred polish to `TKT-M3-06`): update mode, path mode, dictionary/word size, solid block size, CPU threads, split volume size, memory-required estimate, "delete source after", and "encrypt file names". |

## 6. UX / Interaction Design

- **Form**: native sheet with grouped `.formStyle(.grouped)`; primary "Create", secondary "Cancel".
- **Defaults**: format 7z, level "Normal (5)", name derived from selection ("Archive" / "<folder>.7z").
- **Conflict**: `NSAlert` with Replace (destructive), Keep Both, Cancel.
- **Progress**: reuse Tasks popover/status bar; sheet dismisses to background task with toast.
- **Encryption**: password + confirm fields; show "AES-256" for 7z; for ZIP show "AES-256 (if supported)" and disable if the spike proves unsupported.
- **Keyboard**: Return creates when valid, Esc cancels.

## 7. Technical Design

- `CompressionViewModel` (`@MainActor`) holds form state + validation; builds `ArchiveOptions`.
- Calls `ArchiveEngine.createArchive(at:from:options:)` via `TaskCenter.submit`.
- Writes to a temp file in destination directory, moves into place on success (atomic; preserves original on replace-until-success).
- Format-specific switch: `.sevenZip`/`.zip` only in MVP; others rejected with `.unsupportedFormat`.

## 8. Data Models / Interfaces

```swift
struct CompressionRequest: Sendable {
    var sources: [URL]
    var destination: URL
    var format: ArchiveFormat          // .sevenZip | .zip (MVP)
    var level: Int                     // 0...9
    var method: String?                // 7z: "LZMA2"
    var password: String?              // AES-256 for 7z
}
```

## 9. Error Handling

- Validation errors inline (empty name, unwritable dir, unsupported format).
- Conflict resolved before start.
- Engine errors mapped to user text (disk full, permission, OOM, cancel).
- On replace: original untouched until temp archive validated (`7zz t` optional) then atomic replace.

## 10. Performance Requirements

- Form opens **< 150 ms**.
- Creating a 1 GB / 10k-file archive: progress updates ≥ 2/s; UI remains responsive; cancel honored < 3 s.
- No full in-memory buffering of source data (stream via 7zz).

## 11. Security Requirements

- Passwords passed to engine without appearing in logs/UI diagnostics; redact.
- Destination path validated; no writing outside chosen directory.
- Refuse to create an archive inside itself (source contains destination).

## 12. Acceptance Criteria

- **AC-CW-1** — Given 3 selected files, When creating a `.7z` with defaults, Then the archive is created, passes `7zz t`, and contains exactly 3 entries.
- **AC-CW-2** — Given an existing target file, When Create is pressed, Then a Replace/Keep Both/Cancel dialog appears and Cancel leaves the original untouched.
- **AC-CW-3** — Given ZIP format selected, When created, Then a valid ZIP is produced readable by `unzip`/7zz.
- **AC-CW-4** — Given password enabled for 7z, When created, Then listing without password fails and with password succeeds.
- **AC-CW-5** — Given an in-progress create, When Cancel is pressed, Then no final archive exists and no temp files remain.
- **AC-CW-6** — Given TAR format requested (not MVP), Then the engine returns `.unsupportedFormat` and UI states it is unavailable.

## 13. Test Strategy

- Integration: create→test→extract round-trip for 7z and ZIP; encrypted round-trip; cancel mid-operation; conflict paths.
- Unit: validation, name derivation, conflict suffixing, request→argv mapping.
- UI smoke: open dialog, fill, create small archive.

## 14. Dependencies

- SPEC-AE create + test; SPEC-TM; ADR-004/005/009.

## 15. Related ADRs / Tickets

- ADRs: ADR-004, ADR-005, ADR-009
- Tickets: `TKT-M3-01` … `TKT-M3-08`
