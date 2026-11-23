# EPIC-M6 — Performance, Security & Release Hardening

**Milestone:** M6 · **Priority:** P0 (release-blocking) · **Status:** Planned · **Specs:** [SPEC-SEC](../specs/security.md), [SPEC-REL](../specs/release.md)

> **中文摘要**：M6 Epic——发布硬化：大目录/大压缩包性能与内存、恶意压缩包安全测试、x86_64/Universal、签名+公证、DMG、GitHub Releases 自动化、GUI 测试扩展与文档。

## Objective

Take Mac7Zip from feature-complete to a trustworthy, distributable release: measured performance, hardened security test suite, universal binary, signed/notarized DMG+ZIP, and automated GitHub Releases.

## Scope & Ticket breakdown (epic-level)

| ID | Title | Pri | Notes |
|---|---|---|---|
| TKT-M6-01 | Large-directory & large-archive performance/memory tuning | P0 | 100k-entry targets; Instruments-based memory checks; fix hotspots. |
| TKT-M6-02 | Malicious-archive security test suite (CI) | P0 | Traversal, symlink, bomb, corrupt, password; assert fail-closed. |
| TKT-M6-03 | Universal Binary (arm64 + x86_64) build | P1 | `ARCHS="arm64 x86_64"`; `lipo` verification; x86_64 runtime note. |
| TKT-M6-04 | Code signing + notarization pipeline (`release.yml`) | P0 | Developer ID, `notarytool`, staple, verify (ADR-010). |
| TKT-M6-05 | DMG packaging + GitHub Release automation | P0 | `hdiutil`; attach ZIP+DMG; release notes. |
| TKT-M6-06 | XCUITest suite expansion | P1 | Cover browse/archive/extract/compress flows; screenshot artifacts. |
| TKT-M6-07 | Release docs, changelog, THIRD_PARTY_NOTICES | P1 | User-facing + legal. |
| TKT-M6-08 | Reproducibility & version pinning audit | P2 | Pin tools, XcodeGen, 7zz; document. |

## Acceptance Criteria (epic-level)

- **AC-M6-1** — Given a 100k-entry directory/archive, Then load/render meets SPEC performance budgets.
- **AC-M6-2** — Given the malicious-archive suite, Then every unsafe case fails closed with no destination writes.
- **AC-M6-3** — Given a tagged release, Then a notarized universal DMG and ZIP are attached and pass `spctl`/`stapler validate`.
- **AC-M6-4** — Given missing credentials, Then `release.yml` fails clearly and publishes nothing.
- **AC-M6-5** — Given the release, Then `THIRD_PARTY_NOTICES` includes 7-Zip LGPL/unRAR notices.

## Dependencies

- M1–M5 complete; ADR-009/010; Apple Developer account (unconfirmed → signing tickets marked blocked until available).

## Risks / Blockers

- **Blocker:** Developer ID + notarization credentials unavailable → M6-04/05 blocked; dev builds remain unsigned.
- Universal build doubles CI time; x86_64 runtime untestable locally.
- Notarization of a nested helper (`7zz`) is a known failure source; verify early in a spike.
