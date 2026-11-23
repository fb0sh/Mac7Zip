# M6 — Performance, Security & Release Hardening — Tickets

**Milestone:** M6 · **Epic:** EPIC-M6 · **Specs:** [SPEC-SEC](../specs/security.md), [SPEC-REL](../specs/release.md) · **Status:** Planned

> **中文摘要**：M6 工单——大目录/大压缩包性能与内存、恶意压缩包安全套件、Universal 二进制、Developer ID 签名+公证、DMG+GitHub Releases 自动化、XCUITest 扩展、发布文档/第三方声明、可复现性与工具版本审计。全部可实施；签名/公证受账号凭据阻塞。

---

## TKT-M6-01 — Large-directory & large-archive performance/memory tuning

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Hit SPEC performance budgets at 100k entries; Instruments memory audit; fix hotspots (icon cache, snapshot deltas, list parse streaming).
- **Implementation Notes:** Benchmark harness extended; ratio-based CI assertions; record baselines.
- **Dependencies:** TKT-M1-02, TKT-M2-03.
- **Acceptance Criteria:** 100k directory first render < 1.5 s; archive list < 3 s; memory < 150 MB.
- **Tests:** Performance harness in CI.
- **DoD:** CI green; baselines recorded.
- **Related:** SPEC-FM, SPEC-AE · ADR-002, ADR-004

## TKT-M6-02 — Malicious-archive security test suite (CI)

- **Priority:** P0 · **Type:** Test · **Status:** Planned
- **Scope:** Traversal, absolute path, symlink/hardlink escape, special files, zip bomb/ratio, corrupt, wrong password, cancel; assert fail-closed and no writes outside destination.
- **Implementation Notes:** Generate fixtures in CI; run against real engine; assert destination unchanged on violation.
- **Dependencies:** TKT-M2-06, TKT-M2-07, TKT-M2-11.
- **Acceptance Criteria:** All SPEC-SEC guarantees verified automatically.
- **Tests:** The suite itself.
- **DoD:** CI green; zero unsafe writes.
- **Related:** SPEC-SEC · ADR-008

## TKT-M6-03 — Universal Binary (arm64 + x86_64)

- **Priority:** P1 · **Type:** Infrastructure · **Status:** Planned
- **Scope:** Build universal; `lipo -info` verify; both slices include bundled 7zz (or two helper slices); note x86_64 runtime support.
- **Implementation Notes:** `ARCHS="arm64 x86_64"`; 7zz must be universal or per-arch lipo'd; test artifact inspection.
- **Dependencies:** TKT-M2-01.
- **Acceptance Criteria:** `lipo -info` shows both; app launches on each arch (x86_64 via Rosetta/manual).
- **Tests:** CI arch assertions.
- **DoD:** CI green.
- **Related:** SPEC-REL · ADR-009, ADR-010

## TKT-M6-04 — Developer ID signing + notarization (`release.yml`)

- **Priority:** P0 · **Type:** Infrastructure · **Status:** Planned (blocked on credentials)
- **Scope:** Sign app + nested 7zz; hardened runtime; `notarytool submit --wait`; staple; verify (`codesign --verify --deep --strict`, `spctl -a`, `stapler validate`).
- **Implementation Notes:** Protected `release` Environment; secrets for cert + notary; fail clearly if missing; never publish unsigned as official.
- **Dependencies:** TKT-M2-01, TKT-M6-03.
- **Acceptance Criteria:** AC-REL-2, AC-REL-3.
- **Tests:** Release workflow dry-run where possible.
- **DoD:** Signed+notarized artifact passes verification.
- **Related:** SPEC-REL · ADR-010

## TKT-M6-05 — DMG packaging + GitHub Release automation

- **Priority:** P0 · **Type:** Infrastructure · **Status:** Planned (blocked on credentials for signed release)
- **Scope:** Build DMG (`hdiutil`), sign/notarize/verify DMG + ZIP, publish GitHub Release on `v*` tag.
- **Implementation Notes:** Attach ZIP+DMG; release notes; integrity checks before publish.
- **Dependencies:** TKT-M6-04.
- **Acceptance Criteria:** AC-REL-5; both assets notarized.
- **Tests:** Workflow validation; artifact inspection.
- **DoD:** Release published.
- **Related:** SPEC-REL · ADR-010

## TKT-M6-06 — XCUITest suite expansion

- **Priority:** P1 · **Type:** Test · **Status:** Planned
- **Scope:** Cover browse/navigate/sort/select, open archive, extract (incl. drag where feasible), compress dialog; screenshot/log artifacts.
- **Implementation Notes:** Build on the M1 GUI spike; keep smoke stable, quarantine flaky.
- **Dependencies:** TKT-M1-10, TKT-M2-05, TKT-M3-02.
- **Acceptance Criteria:** Smoke suite passes on `macos-26`; artifacts uploaded.
- **Tests:** The UI suite.
- **DoD:** CI green.
- **Related:** SPEC-REL · ADR-010

## TKT-M6-07 — Release docs, changelog & third-party notices

- **Priority:** P1 · **Type:** Documentation · **Status:** Planned
- **Scope:** User-facing release notes, changelog, `THIRD_PARTY_NOTICES.md` (7-Zip LGPL/unRAR), privacy note.
- **Implementation Notes:** Keep notices in sync with bundled 7zz version.
- **Dependencies:** TKT-M2-01, TKT-M5-05.
- **Acceptance Criteria:** Notices complete; changelog generated per release.
- **Tests:** Doc/notice presence check.
- **DoD:** Docs merged.
- **Related:** SPEC-REL · ADR-009

## TKT-M6-08 — Reproducibility & tool-version pinning audit

- **Priority:** P2 · **Type:** Infrastructure · **Status:** Planned
- **Scope:** Pin XcodeGen/SwiftLint/swift-format/7zz; audit `otool -L`; document reproducible build steps.
- **Implementation Notes:** Lockfile/version files; CI checks versions.
- **Dependencies:** TKT-M1-10.
- **Acceptance Criteria:** Versions pinned and checked; dependency audit clean.
- **Tests:** CI version-check step.
- **DoD:** CI green.
- **Related:** SPEC-REL · ADR-009, ADR-010
