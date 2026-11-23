# SPEC-AE — Archive Engine

**Status:** Accepted · **Milestone:** M2 (MVP) · **Last updated:** 2026-11-23

> **中文摘要**：压缩引擎规格——`SevenZipEngine` 通过子进程调用打包的 `7zz`，实现列出/解压/测试/密码；定义格式能力矩阵、进程生命周期、输出解析、退出码映射与安全钩子。MVP 创建 7z/ZIP、读取/解压 7z/ZIP/TAR/GZIP/BZIP2/XZ 与只读 RAR。

## 1. Overview

The archive engine isolates all archive work behind `ArchiveEngine`. It launches the bundled `7zz` (ADR-004/009), streams output, parses listings/progress, enforces security policy (ADR-008), and reports structured results. It knows nothing about SwiftUI.

## 2. Goals

- Reliable list/extract/test for MVP formats; create for 7z/ZIP.
- Robust, cancellable subprocess execution with no deadlocks or leaks.
- Structured, testable parsing of 7zz output.
- Security-enforcing extraction path (fail-closed).

## 3. Non-goals

- RAR creation (unRAR restriction forbids it).
- GUI, progress presentation, task queueing (those are SPEC-TM/UI).
- Universal/Virtual FS mounting (SPEC-AB).
- Create for TAR/GZIP/BZIP2/XZ/WIM in MVP (P2).

## 4. User Scenarios

- **S1**: Open a `.7z`/`.zip` → engine lists entries (path, size, isDir, date, encrypted flag).
- **S2**: Extract all to a chosen folder → validated, staged, reported.
- **S3**: Extract selected entries only.
- **S4**: Test integrity → pass/fail with message + exit-code mapping.
- **S5**: Encrypted archive without/with wrong password → typed `.wrongPassword`/`.passwordRequired`.
- **S6**: Corrupt archive → `.corrupt` with 7zz diagnostic excerpt.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-AE-01 | `SevenZipEngine.listContents(of:)` returns `[ArchiveEntry]` parsed from `7zz l -slt -sccUTF-8`. |
| FR-AE-02 | `SevenZipEngine.extract(...)` supports all/selected, optional password, into a validated destination. |
| FR-AE-03 | `SevenZipEngine.test(archive:)` runs `7zz t` and maps result. |
| FR-AE-04 | Create archives (`7z`, `zip`) with level/method; passwords for 7z (AES-256). |
| FR-AE-05 | All operations run as subprocesses read concurrently on stdout+stderr; no pipe deadlock. |
| FR-AE-06 | Map exit codes: 0=ok, 1=warning, 2=fatal, 7=cli, 8=oom, 255=cancelled. |
| FR-AE-07 | Emit progress (0–100%) parsed from `-bsp1`, or `nil` when indeterminate. |
| FR-AE-08 | Pre-flight + post-extraction security enforcement per ADR-008 (fail-closed). |
| FR-AE-09 | Password transport: **fail closed by default** (`.passwordTransportUnavailable`) because 7-Zip 26.06's prompt is console-bound and ignores piped stdin and `script(1)` PTYs (empirically verified). Explicit `argvExplicit` opt-in uses `-p<password>` and is documented as `ps`-visible. Never silently fall back; `-si` is data-stream, not password; redact diagnostics. |
| FR-AE-10 | Honor cancellation: SIGINT → grace → SIGTERM → SIGKILL; clean staging temps. |
| FR-AE-11 | Support UTF-8 filenames (`-sccUTF-8`) and NFC/NFD normalization handling. |
| FR-AE-12 | Extract supports: destination, "extract to subfolder `<name>/`", path mode (full/relative), eliminate-duplicate-root, overwrite mode (ask/overwrite/skip/rename), password, and restore-file-security-settings. |
| FR-AE-13 | Provide "Extract here" and "Extract to `<archiveName>/`" convenience targets (used by double-click-extract and drag-out). |

## 6. UX / Interaction Design

Engine has no direct UI. It surfaces typed results to SPEC-TM/UI. Progress is a `Double?`; indeterminate shows a spinner. Errors carry an actionable `message` and optional `diagnosticSnippet` (never secrets).

## 7. Technical Design

- `final class SevenZipEngine: ArchiveEngine` (`Sendable` via actor confinement or `@unchecked Sendable` with strict internal locking — prefer running inside `TaskCenter` actor).
- Locates helper: `Bundle.main.url(forAuxiliaryExecutable:)` / `Contents/Helpers/7zz`.
- Builds `Process` + `Pipe`s; uses `readabilityHandler` to feed `AsyncStream<String>`; a dedicated `OutputParser` transforms lines into events (`entry`, `progress`, `diagnostic`, `done`).
- Listing: parse `-slt` blocks (`Path = ...`, `Size = ...`, `Folder = +`, `Modified = ...`, `Encrypted = +`).
- Extraction command: `7zz x archive -o<staging> -y [-p<pw>] -bsp1 -bso1 -bse2 -sccUTF-8 [entries...]`.
- After staging success and validation, atomically move staged items into destination.

## 8. Data Models / Interfaces

```swift
enum ArchiveFormat: String, Sendable, CaseIterable { case sevenZip = "7z", zip, tar, gzip, bzip2, xz }

struct ArchiveEntry: Identifiable, Sendable {
    let id = UUID(); let path: String; let size: Int64
    let isDirectory: Bool; let modified: Date?; let isEncrypted: Bool
}

struct ArchiveOptions: Sendable { var format: ArchiveFormat = .sevenZip; var password: String?; var level: Int = 5; var method: String? }
struct ExtractOptions: Sendable {
    var password: String?
    var entries: [String]?              // nil = all entries
    var destination: URL
    var createSubfolder: String?        // e.g. "<archiveName>"; nil = extract directly
    var pathMode: ExtractPathMode       // .full | .relative
    var eliminateDuplicateRoot: Bool
    var overwriteMode: OverwriteMode    // .ask | .overwrite | .skip | .rename
    var restorePermissions: Bool
}
enum ExtractPathMode: Sendable { case full, relative }
enum OverwriteMode: Sendable { case ask, overwrite, skip, rename }

enum ArchiveError: Error, Equatable {
    case passwordRequired; case wrongPassword; case corrupt(String)
    case unsupportedFormat(String); case unsafeEntry(paths: [String], reason: String)
    case cancelled; case outOfMemory; case engineFailure(code: Int32, diagnostic: String)
}
```

## 9. Error Handling

- Distinguish wrong vs missing password via 7zz diagnostics + exit code; map to typed errors.
- Corrupt archive → `.corrupt(diagnosticSnippet)`.
- Unknown format → `.unsupportedFormat`.
- Security violation → `.unsafeEntry` with offending paths.
- Never expose passwords in `diagnostic`.

## 10. Performance Requirements

- List a 100k-entry archive in **< 3 s** (parse streaming, not full-buffer string concatenation).
- Extraction throughput bounded by disk; streaming progress granularity ≤ 250 ms UI updates.
- Memory overhead of parser **< 20 MB** for 100k entries (stream, don't retain raw output beyond a bounded buffer).

## 11. Security Requirements

- Enforce ADR-008 before and during extraction; staging dir; atomic move; delete temps on any failure/cancel.
- Reject absolute/traversal/symlink-escape/special files; enforce size/ratio limits.
- Redact secrets from logs; use `-p` only in-process; prefer stdin where 7zz supports it.

## 12. Acceptance Criteria

- **AC-AE-1** — Given a valid `.7z`, When listed, Then entries match 7zz ground truth (path/size/folder/date).
- **AC-AE-2** — Given a `.zip` with 3 entries, When extracting selected 2, Then only those appear in destination.
- **AC-AE-3** — Given a wrong password archive, When extracting with wrong password, Then `.wrongPassword` and no files written.
- **AC-AE-4** — Given a traversal archive (`../evil`), When extracting, Then `.unsafeEntry` and destination unchanged.
- **AC-AE-5** — Given a long extraction, When cancelled, Then process exits, state `cancelled`, no staging leftovers.
- **AC-AE-6** — Given exit code 1 warning (e.g., locked file), Then result is success-with-warning surfaced to user.

## 13. Test Strategy

- Fixture archives in `Tests/Fixtures/` (valid 7z/zip/tar.gz, encrypted, wrong-password, corrupt, traversal, symlink, bomb-ratio).
- Parser unit tests against captured raw `7zz` output files (golden files).
- Integration tests invoking the real bundled `7zz` on fixtures (run on CI).
- Cancellation test with a large generated archive.

## 14. Dependencies

- Bundled `7zz` (ADR-009), `TaskCenter` (ADR-005), `SecurityValidator` (ADR-008).

## 15. Related ADRs / Tickets

- ADRs: ADR-004, ADR-005, ADR-008, ADR-009
- Tickets: `TKT-M2-01` … `TKT-M2-16`
