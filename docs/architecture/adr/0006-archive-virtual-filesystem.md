# ADR-006 — Archive Virtual Filesystem Design

**Status:** Accepted · **Date:** 2026-11-23

> **中文摘要**：在 M1 重构中引入极简 `FileSystemProvider` 协议（list/metadata/capabilities），真实文件系统提供者可读写，压缩包提供者只读；用 `BrowserLocation` 明确区分真实路径与包内路径；不做通用虚拟文件系统模拟。

## Context

Phase 4 requires browsing inside archives. Phase 1 (M1) already needs a seam so the browser isn't hard-wired to `FileManager`. The user asked (Round 2, Q4) for a minimal provider introduced in M1, real provider in M1, read-only archive provider in M2, without speculative emulation.

## Decision Drivers

- One browser UI must render both real directories and archive trees.
- Archive entries have different semantics: read-only, no POSIX permissions, sizes may be estimates.
- Must prevent archive-internal paths from reaching `FileManager`.
- Keep it small and test-driven.

## Considered Options

1. **Separate archive browser UI** (duplicate table/logic): rejected — duplication, divergent UX.
2. **Minimal `FileSystemProvider` protocol with capability flags (chosen)**.
3. Full virtual filesystem with write/rename/mount semantics: over-engineered, error-prone.

## Decision

```swift
struct FSCapabilities: OptionSet, Sendable {
    let rawValue: Int
    static let list            = FSCapabilities(rawValue: 1 << 0)
    static let readFile        = FSCapabilities(rawValue: 1 << 1)
    static let writeFile       = FSCapabilities(rawValue: 1 << 2)
    static let rename          = FSCapabilities(rawValue: 1 << 3)
    static let delete          = FSCapabilities(rawValue: 1 << 4)
    static let createDirectory = FSCapabilities(rawValue: 1 << 5)
}

protocol FileSystemProvider: Sendable {
    var kind: ProviderKind { get }              // .real | .archive
    var capabilities: FSCapabilities { get }
    func list(_ location: BrowserLocation) async throws -> [FileEntry]
}

struct FileEntry: Identifiable, Hashable, Sendable {
    let id: EntryID            // stable within a provider/location
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let kind: String           // display kind, e.g. "Folder", "ZIP document"
}
```

- `RealFileSystemProvider` (M1): `capabilities = [.list,.readFile,.writeFile,.rename,.delete,.createDirectory]`.
- `ArchiveFileSystemProvider` (M2): `capabilities = [.list]` (read-only), backed by `7zz l -slt` (ADR-004/005). It **never** yields a real `URL` for members.
- `BrowserLocation.archive(archiveURL:internalPath:)` carries the archive's real URL separately from the opaque internal path; only the archive provider interprets `internalPath`.
- UI reads `capabilities` to enable/disable actions, so archive listings automatically grey out rename/delete/new-folder.

## Rationale

A tiny protocol with explicit capabilities cleanly unifies browsing while making semantic differences impossible to ignore. It is just enough to build M2 without committing to a full VFS.

## Consequences

- `FileItem` (Phase 0) generalizes to `FileEntry`; `FileSystemService` becomes `RealFileSystemProvider`.
- Ambiguous operations on archives are prevented by capabilities rather than runtime checks scattered in UI.
- Archive metadata gaps (unknown permissions, approximate sizes) are documented, not faked.

## Risks / Trade-offs

- Capability flags can drift from actual provider behavior → contract tests per provider.
- Some future formats (nested archives, in-memory) may need a `.virtual` kind; the enum is extensible.

## Related

- Specs: `SPEC-AB`, `SPEC-FM`
- ADRs: ADR-003, ADR-004
- Tickets: `TKT-M1-01`, `TKT-M2-04`, `TKT-M2-05`
