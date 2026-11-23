# SPEC-SEC — Security Model

**Status:** Accepted (policy) / Proposed (numeric limits, sandbox appendix) · **Milestones:** M1, M2, M5 · **Last updated:** 2026-11-23

> **中文摘要**：安全模型规格——所有磁盘访问经 `FileAccess` 边界并处理 TCC/权限拒绝；对不可信压缩包采用“失败即中止”的解压策略（校验前置+解压中强制限制、暂存目录、原子落地）；密码与日志脱敏；附未来 App Sandbox 方案。具体数值限制标记为 Proposed。

## 1. Overview

Two threat surfaces: (a) **filesystem access** (permissions, TCC, path handling) and (b) **untrusted archives** (traversal, links, bombs, corruption). This spec defines enforceable rules and testable guarantees. It complements ADR-007 (access) and ADR-008 (extraction).

## 2. Goals

- Never write outside the user-selected destination because of an archive.
- Never crash on malformed/malicious/denied inputs; always produce actionable errors.
- Keep secrets (passwords) out of logs, diagnostics, and argv where avoidable.
- Preserve a clean path to a sandboxed distribution later.

## 3. Non-goals

- Guaranteeing protection against kernel/OS-level exploits inside 7zz (we isolate via subprocess; we don't audit 7zz's C++).
- Antivirus/malware scanning of archive contents.
- Encrypted-archive password vault persistence.
- App Sandbox/MAS implementation in MVP (appendix only).

## 4. User Scenarios

- **S1**: Navigate to `~/Documents` → system TCC prompt → allow → listing appears; deny → actionable message.
- **S2**: Extract a malicious archive with `../../evil` → operation aborts, destination untouched, error names the entry.
- **S3**: Extract a zip bomb (ratio 1000:1) → aborts at ratio limit.
- **S4**: Wrong password → typed error, retry; password never written to logs.
- **S5**: Archive contains a symlink to `/etc/passwd` → rejected before writing.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-SEC-01 | All disk access goes through `FileAccess`; no direct `FileManager` calls in UI/State. |
| FR-SEC-02 | Map `NSFileReadNoPermissionError`/`EACCES`/`EPERM` → `.accessDenied`; show guidance. |
| FR-SEC-03 | Pre-flight validate every archive entry: reject absolute paths, `..` traversal, out-of-root canonicalization. |
| FR-SEC-04 | Reject symlink/hardlink entries that escape root (MVP: reject all links). |
| FR-SEC-05 | Reject device nodes, FIFOs, sockets. |
| FR-SEC-06 | Enforce max total uncompressed size and max expansion ratio (configurable, conservative defaults). |
| FR-SEC-07 | Extract into a controlled staging dir; move into destination only on success (atomic). |
| FR-SEC-08 | Post-extraction re-validate created links/paths; abort if limits exceeded during extraction. |
| FR-SEC-09 | On violation: abort, delete staging, return offending paths; destination unchanged. |
| FR-SEC-10 | Redact `-p…` and password args from logs/diagnostics; never persist passwords in task history. |
| FR-SEC-11 | Treat TOCTOU explicitly: staging + validate-before-move; never follow attacker symlinks during move. |

## 6. UX / Interaction Design

- **Access denied**: alert with message + "Open System Settings › Privacy & Security" button (M5) + "Reveal in Finder" when applicable.
- **Unsafe archive**: dialog listing offending entries (up to N) and reason; "Cancel" only.
- **Limits exceeded**: message states which limit and the observed value.
- No security decision is silent; every refusal is explained.

## 7. Technical Design

- `FileAccess` (real impl) is the only `FileManager` consumer.
- `SecurityValidator` operates on `[ArchiveEntry]` before extraction and on filesystem state during/after.
- `StagingArea` creates a unique dir under `FileManager.default.temporaryDirectory` (app-scoped), records ownership, and guarantees cleanup.
- Canonicalization: resolve `.`/`..`, reject non-normalized absolutes; compare against destination root using standardized URLs; on move, re-check.

## 8. Data Models / Interfaces

```swift
enum SecurityViolation: Equatable {
    case absolutePath(String); case traversal(String); case symlinkEscape(String)
    case specialFile(String); case sizeLimitExceeded(total: Int64, limit: Int64)
    case ratioExceeded(entry: String, ratio: Double)
}

struct ExtractionLimits: Sendable {          // Proposed defaults
    var maxTotalBytes: Int64 = 4 * 1024 * 1024 * 1024   // 4 GiB default; also capped by free space
    var maxExpansionRatio: Double = 100                  // 100:1
    var maxEntryCount: Int = 1_000_000
}

protocol SecurityValidating: Sendable {
    func validate(_ entries: [ArchiveEntry], destination: URL, limits: ExtractionLimits) throws
}
```

## 9. Error Handling

- Violations map to `ArchiveError.unsafeEntry(paths:reason:)`.
- Limit defaults are overridable in settings (M5); if unlimited requested, require explicit confirmation.
- Never partially extract unsafe output; if staging already has data, delete before returning.

## 10. Performance Requirements

- Validation of 100k entries **< 500 ms** (stream, single pass).
- Staging check of free space before extraction; refuse early if insufficient.
- Post-extraction verification proportional to created items, not archive size.

## 11. Security Requirements

- These are the authoritative guarantees:
  1. No archive entry can cause a write outside the destination root.
  2. Unsafe archives are refused wholesale (no silent partial output).
  3. Passwords never appear in logs, diagnostics, or task history.
  4. Denied permissions produce a clear error, never a crash.
  5. Temp/staging dirs are removed on success, failure, and cancellation.

## 12. Acceptance Criteria

- **AC-SEC-1** — Given an archive with `../evil`, When extracting, Then `.unsafeEntry` and destination has no new files.
- **AC-SEC-2** — Given a symlink escaping root, When extracting, Then it is rejected and reported.
- **AC-SEC-3** — Given a ratio 500:1 archive with default limit 100:1, When extracting, Then aborts with `.ratioExceeded`.
- **AC-SEC-4** — Given a protected folder the user denies, When navigating, Then an actionable access-denied state appears.
- **AC-SEC-5** — Given a wrong password, Then error shows and grep of all logs finds no plaintext password.
- **AC-SEC-6** — Given cancellation during extraction, Then no staging dir remains.

## 13. Test Strategy

- Fixture-based unit tests for `SecurityValidator` (traversal, absolute, links, special files, ratios).
- Integration with real 7zz for bomb/traversal fixtures.
- Log-redaction test scanning captured logs for the test password.
- TCC/access-denied tested via chmod fixtures (best-effort in CI; full TCC manual on macOS).

## 14. Dependencies

- ADR-007 (FileAccess), ADR-008 (policy), SPEC-AE engine.

## 15. Related ADRs / Tickets

- ADRs: ADR-007, ADR-008, ADR-004
- Tickets: `TKT-M1-07`, `TKT-M2-06`, `TKT-M2-11`, `TKT-M5-02`

## Appendix — Future App Sandbox (Proposed, not MVP)

If Mac App Store or sandboxing is pursued: enable App Sandbox; add `com.apple.security.files.user-selected.read-write`; use security-scoped bookmarks for persistent favourite roots; move all access behind `FileAccess`; archive staging remains in the container temp. This appendix does not commit to MAS.
