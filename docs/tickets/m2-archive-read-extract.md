# M2 — Archive Read & Extract (MVP) — Tickets

**Milestone:** M2 · **Specs:** [SPEC-AE](../specs/archive-engine.md), [SPEC-AB](../specs/archive-browser.md), [SPEC-TM](../specs/task-management.md), [SPEC-SEC](../specs/security.md) · **Status:** Planned

> **中文摘要**：M2 工单——打包 7zz、进程运行器、输出解析、只读包内文件系统、进入/浏览压缩包、安全校验、解压流水线、TaskCenter 与取消清理、完整性测试与密码、集成/安全测试。

---

## TKT-M2-01 — Vendor 7zz (pinned, checksum, license, nested signing)

- **Priority:** P0 · **Type:** Infrastructure · **Status:** Planned
- **Background:** Engine requires a bundled `7zz`; license/signing obligations must be met. (ADR-009)
- **Scope:** Add `Vendor/7zz/<version>/7zz`, `LICENSE-7ZIP.txt`, `NOTICE.md`, `SHA256SUMS`; verify checksum; bundle into `Contents/Helpers/`; configure nested codesign. Packaging **spike** resolves exact arm64 artifact.
- **Implementation Notes:** Fetch official `7z<ver>-mac.tar.xz` ([7-zip.org/download.html](https://7-zip.org/download.html)); if not arm64-only, record contingency (build from source). Verify `7zz i` reports version matching NOTICE.
- **Dependencies:** None (blocking for M2).
- **Acceptance Criteria:** `7zz` runs on `macos-26` arm64 from bundle path; `7zz i` version equals pinned; checksum verified in CI; license/notice present in app resources.
- **Tests:** CI step asserting `7zz i` and checksum; artifact inspection.
- **DoD:** Helper present, signed (ad-hoc ok for dev), license shipped.
- **Related:** SPEC-REL, SPEC-AE · ADR-009

## TKT-M2-02 — SevenZipEngine process runner

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** `Process`-based runner: concurrent stdout/stderr read, exit-code mapping, timeout, structured result. Commands: list/extract/test/create.
- **Implementation Notes:** Use `readabilityHandler`; avoid pipe deadlock; `terminationHandler` captures status; locate helper via `Bundle.main`.
- **Dependencies:** TKT-M2-01.
- **Acceptance Criteria:** Runs each command on fixtures; exit codes mapped to `ArchiveError`; no deadlock at high output.
- **Tests:** Runner unit tests with a fake script; integration with real 7zz.
- **DoD:** CI green.
- **Related:** SPEC-AE · ADR-004, ADR-005

## TKT-M2-03 — Output adapter & parsers (+ golden fixtures)

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Parse `l -slt` listings, `-bsp1` progress percentages, and diagnostics into typed events; capture golden raw outputs for tests.
- **Implementation Notes:** Record raw 7zz output for fixtures; parser is pure and unit-tested; document grammar; mark uncertain grammar as validated-in-spike.
- **Dependencies:** TKT-M2-02.
- **Acceptance Criteria:** Listing parse matches ground truth for all fixture archives; progress yields 0–100 or nil; diagnostics parsed.
- **Tests:** Golden-file parser tests.
- **DoD:** CI green.
- **Related:** SPEC-AE · ADR-004, ADR-005

## TKT-M2-04 — ArchiveFileSystemProvider (read-only)

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Implement `FileSystemProvider` for archives with `capabilities=[.list]`, per-archive listing cache, directory filtering by internal path.
- **Implementation Notes:** `BrowserLocation.archive` only; never produce real `URL`s for members; cache invalidation on refresh.
- **Dependencies:** TKT-M1-01, TKT-M2-03.
- **Acceptance Criteria:** Lists entries matching engine; capability flags disable mutations; no archive path becomes a URL.
- **Tests:** Provider contract + filtering tests.
- **DoD:** CI green.
- **Related:** SPEC-AB · ADR-006

## TKT-M2-05 — Enter/navigate archive in browser

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Double-click archive → enter root; navigate internal dirs; breadcrumb shows archive chip + segments; Enclosing Folder exits to real parent.
- **Implementation Notes:** Reuse `BrowserStore` with `.archive`; read-only badge in status bar; empty-archive state.
- **Dependencies:** TKT-M2-04.
- **Acceptance Criteria:** AC-AB-1..5 pass.
- **Tests:** Integration + UI smoke.
- **DoD:** CI green.
- **Related:** SPEC-AB · ADR-006, ADR-003

## TKT-M2-06 — SecurityValidator (pre-flight + limits)

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Validate entries before extraction; reject absolute/traversal/symlink-escape/special files; enforce size/ratio limits; return offending paths. (ADR-008)
- **Implementation Notes:** Canonicalize against destination; `ExtractionLimits` configurable; post-extraction re-check hooks.
- **Dependencies:** TKT-M2-03.
- **Acceptance Criteria:** AC-SEC-1..3 pass; validation < 500 ms for 100k entries.
- **Tests:** Fixture-based validator tests.
- **DoD:** CI green.
- **Related:** SPEC-SEC · ADR-008

## TKT-M2-07 — Extract all/selected pipeline + UI

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Extract all/selected via `TaskCenter`; staging dir; atomic move; progress; on violation abort + cleanup.
- **Implementation Notes:** `7zz x ... -o<staging>`; validate before; monitor limits during; move on success.
- **Dependencies:** TKT-M2-02, TKT-M2-06, TKT-M2-08.
- **Acceptance Criteria:** AC-AE-2; AC-SEC-1/2; cancelled/failed leaves no destination changes.
- **Tests:** Integration round-trip; security fixtures.
- **DoD:** CI green.
- **Related:** SPEC-AE, SPEC-SEC · ADR-005, ADR-008

## TKT-M2-08 — TaskCenter + Tasks popover/progress

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** `actor TaskCenter` with queue, lifecycle, bounded history; `@MainActor` adapter; status-bar progress + Tasks popover.
- **Implementation Notes:** Default concurrency 1; snapshot coalescing ≤10 Hz; no SwiftUI import in TaskCenter.
- **Dependencies:** TKT-M2-02.
- **Acceptance Criteria:** AC-TM-1..4 pass.
- **Tests:** State-machine unit tests.
- **DoD:** CI green.
- **Related:** SPEC-TM · ADR-005

## TKT-M2-09 — Cancellation & cleanup

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Graceful→forced cancellation; SIGINT/terminate/kill; staging/temp cleanup; state `cancelled`.
- **Implementation Notes:** Grace 3 s then SIGTERM then SIGKILL; reap process; delete staging.
- **Dependencies:** TKT-M2-08.
- **Acceptance Criteria:** AC-AE-5, AC-SEC-6 pass; no orphan processes.
- **Tests:** Cancellation integration test.
- **DoD:** CI green.
- **Related:** SPEC-TM · ADR-005

## TKT-M2-10 — Test integrity + password prompt flow

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** `7zz t` via TaskCenter; password prompt for encrypted archives; retry on wrong password.
- **Implementation Notes:** Password passed securely; redact logs; distinguish required vs wrong.
- **Dependencies:** TKT-M2-02, TKT-M2-03.
- **Acceptance Criteria:** AC-AE-3 passes; test command reports pass/fail; password never logged.
- **Tests:** Integrity + password fixtures.
- **DoD:** CI green.
- **Related:** SPEC-AE, SPEC-SEC · ADR-004, ADR-008

## TKT-M2-11 — Integration & security tests + fixtures

- **Priority:** P0 · **Type:** Test · **Status:** Planned
- **Scope:** Fixtures (valid/encrypted/corrupt/traversal/symlink/bomb) + integration tests for list/extract/test/cancel/security.
- **Implementation Notes:** Generate fixtures in CI deterministically; avoid committing large binaries where possible.
- **Dependencies:** TKT-M2-06, TKT-M2-07, TKT-M2-09.
- **Acceptance Criteria:** All M2 acceptance scenarios covered; runs on `macos-26`.
- **Tests:** The tests themselves.
- **DoD:** CI green; no flaky tests.
- **Related:** SPEC-AE, SPEC-SEC · ADR-008, ADR-010
