# ADR-007 — File Permissions, Sandbox and Security Access Strategy

**Status:** Accepted · **Date:** 2026-11-23

> **中文摘要**：初期通过 GitHub Releases 直接分发，不启用 App Sandbox，使用 Hardened Runtime + Developer ID + 公证；引入极简 `FileAccess` 边界隔离权限并处理 TCC 拒绝错误，为未来沙盒/MAS 变体预留扩展点。

## Context

Mac7Zip browses the user's Home and arbitrary volumes and performs file operations. macOS gates some locations (Desktop/Documents/Downloads) behind TCC even for non-sandboxed apps. Distribution is direct (GitHub Releases), so App Sandbox is optional; Mac App Store is deferred. The user decided (Round 2, Q2) sandbox off initially, with a `FileAccess` boundary for a future sandboxed build.

## Decision Drivers

- A file manager needs broad filesystem reach; the sandbox would force per-directory user grants.
- Direct notarized distribution does not require sandbox.
- Must handle TCC/access-denied gracefully, never crash.
- Keep a clean seam so a sandboxed/MAS build is possible later.

## Considered Options

1. **App Sandbox now** with security-scoped bookmarks: MAS-ready and safer, but heavy UX (grant each root) and blocks M1–M3 velocity now.
2. **No sandbox; Hardened Runtime + notarization (chosen)**: full access, standard for direct-distributed pro tools.
3. No sandbox, no access abstraction: rejected — no path to sandbox later.

## Decision

- Ship **non-sandboxed** initially; releases use **Hardened Runtime** + Developer ID signing + notarization (ADR-010).
- Introduce a minimal **`FileAccess`** protocol wrapping `FileManager`:
  ```swift
  protocol FileAccess: Sendable {
      func contents(of url: URL) async throws -> [FileEntry]
      func attributes(of url: URL) async throws -> FileAttributes
      func perform(_ operation: FileOperation) async throws
  }
  ```
  Real implementation is `FileManager`-backed; maps `NSFileReadNoPermissionError`/`EACCES`/`EPERM` to a typed `.accessDenied(path)` error surfaced as actionable UI.
- Respect TCC: on first access to protected folders, defer to the system prompt; if denied, show an explanatory error and a "Open System Settings → Privacy" affordance (M5 refinement).
- Keep the entitlement surface empty now; document the future sandbox entitlements (`com.apple.security.files.user-selected.read-write`, security-scoped bookmarks) in SPEC-SEC.
- Never assume POSIX permission bits are available for archive entries (see ADR-006).

## Rationale

Matches the professional-tool expectation of full filesystem access while keeping a tested, single choke point for permission errors and a credible path to sandboxing later. Avoids paying the sandbox UX tax before validation.

## Consequences

- All disk access must go through `FileAccess` (review-enforced) so a sandboxed variant can be swapped in.
- Access-denied is a first-class UI state (empty/failed states in SPEC-FM).
- MAS support remains a documented future (SPEC-SEC Appendix).

## Risks / Trade-offs

- Users on managed Macs may still face MDM/TCC limits → clear diagnostics required.
- Non-sandboxed app cannot be distributed on MAS without a separate sandboxed target → accepted, deferred.
- `FileAccess` abstraction could be over-built; keep it to the operations actually used.

## Related

- Specs: `SPEC-SEC`, `SPEC-FM`
- ADRs: ADR-008, ADR-010
- Tickets: `TKT-M1-07`, `TKT-M5-02`
