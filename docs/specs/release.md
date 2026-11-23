# SPEC-REL — CI, Build, Signing, Notarization & Release

**Status:** Accepted (build/test) / Proposed (notarization) · **Milestones:** M1, M6 · **Last updated:** 2026-11-23

> **中文摘要**：发布规格——`build.yml` 无签名、无密钥，覆盖静态检查、单测、集成测试、Release 构建、架构与依赖检查、产物上传；`release.yml` 由版本标签触发，经受保护环境注入凭据完成签名/公证/装订/DMG+ZIP 与校验；GUI 验收采用 CI XCUITest 冒烟 + 真机人工清单。

## 1. Overview

All macOS build verification happens on GitHub Actions (developers have no local Mac). This spec defines the layered verification pipeline, artifact expectations, and the signed-release process (dormant until credentials exist).

## 2. Goals

- Reproducible unsigned builds on every PR/push.
- Layered checks: static → unit → integration → build/arch → GUI smoke.
- A secure, credentials-gated release path that never publishes unsigned artifacts as official.
- Clear diagnostics on failure.

## 3. Non-goals

- Mac App Store submission.
- Automatic nightly releases.
- Universal binary in MVP (arm64 first; universal in M6).
- Building 7zz from source (contingency in ADR-009).

## 4. User Scenarios

- **S1 (dev)**: Open PR → CI compiles, lints (non-blocking), runs tests, uploads unsigned app ZIP.
- **S2 (release)**: Tag `v0.2.0` → protected env approval → signed+notarized DMG/ZIP attached to GitHub Release.
- **S3 (no creds)**: Release job fails with clear "credentials missing" diagnostics; nothing published.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-REL-01 | `build.yml` triggers on push/PR/dispatch; selects & asserts Xcode 26.x. |
| FR-REL-02 | Static: `swift-format lint` + SwiftLint, pinned versions, non-blocking initially. |
| FR-REL-03 | Unit tests host-free; integration tests with fixtures; both run on `macos-26`. |
| FR-REL-04 | Release build + `lipo -info` arch assertion (arm64) + `otool -L` dependency audit. |
| FR-REL-05 | Upload unsigned `.app` ZIP artifact; upload logs on failure. |
| FR-REL-06 | `release.yml` on `v*` tag with protected `release` Environment (required reviewer). |
| FR-REL-07 | Sign app + nested `7zz` helper (Developer ID, `--timestamp`, `-o runtime`). |
| FR-REL-08 | `notarytool submit --wait`, `stapler staple`, verify with `codesign --verify --deep --strict`, `spctl -a`, `stapler validate` before publish. |
| FR-REL-09 | Produce signed+notarized ZIP and DMG; publish both as GitHub Release assets. |
| FR-REL-10 | Missing credentials → fail clearly, never publish unsigned official artifact. |
| FR-REL-11 | XCUITest smoke (launch/navigate/sort/select) with screenshot+log artifacts (infrastructure spike first). |
| FR-REL-12 | Manual acceptance checklist for visual/Liquid Glass/keyboard fidelity before release. |

## 6. UX / Interaction Design

N/A (CI/release). Developer-facing: workflow summaries, uploaded artifacts, clear error annotations. Release notes auto-generated from commits/tags.

## 7. Technical Design

- Reuse `project.yml` + XcodeGen on CI (no committed `.xcodeproj`).
- `build.yml`: matrix-free single job on `macos-26`; parallelizable later (lint vs test vs build).
- `release.yml`: `environment: release`; secrets: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `AC_API_KEY`/`AC_API_ISSUER`/`AC_API_KEY_ID` (or Apple ID app-specific password). Import cert into temporary keychain, sign, notarize, staple, verify, upload.
- CI caches Homebrew/XcodeGen where safe; no caching of build products across incompatible Xcode.
- Artifacts: `Mac7Zip-arm64.zip` (dev) and release `Mac7Zip-<version>.zip` + `.dmg`.

## 8. Data Models / Interfaces

GitHub Actions workflow contracts (job names, required secrets, environment). A `scripts/verify_release.sh` encapsulates signature/notarization assertions for local reuse.

## 9. Error Handling

- Any step failure → workflow failure (nonzero).
- Missing secrets → explicit `::error::` with remediation.
- Notarization rejection → print notary log (`notarytool log`) before failing.
- Arch/dependency check failure → fail the build.

## 10. Performance Requirements

- `build.yml` debug+test **< 10 min** on `macos-26` (excluding queue).
- `release.yml` end-to-end (incl. notarization wait) **< 30 min** typical.
- Artifact upload from existing `ditto` zip (proven in Phase 0).

## 11. Security Requirements

- Secrets only in protected environment; never on PR builds.
- Temporary keychain created and deleted in the job; least-privilege token scopes.
- Pinned action versions (or SHA) for supply-chain integrity.
- No secrets in logs; redact.

## 12. Acceptance Criteria

- **AC-REL-1** — Given a push to `main`, When CI runs, Then compile+unit+integration pass and an unsigned artifact is uploaded.
- **AC-REL-2** — Given a successful release run, Then `codesign --verify --deep --strict` and `spctl -a -vv` pass on the published app, and `stapler validate` succeeds.
- **AC-REL-3** — Given missing credentials, When `release.yml` runs, Then it fails with a clear message and publishes nothing.
- **AC-REL-4** — Given the artifact, Then `lipo -info` reports arm64 and `otool -L` shows only expected system/dependency libraries (plus bundled helper).
- **AC-REL-5** — Given a tagged release, Then both ZIP and DMG assets are attached and notarized.

## 13. Test Strategy

- CI is the test harness; add integration fixtures and release dry-run (sign with a throwaway/ad-hoc identity where possible).
- `scripts/verify_release.sh` unit-checked against the dev artifact.
- GUI smoke spike verified before relying on it.

## 14. Dependencies

- ADR-009 (7zz packaging/signing), ADR-010 (workflow split), Apple Developer account (unconfirmed).

## 15. Related ADRs / Tickets

- ADRs: ADR-009, ADR-010
- Tickets: `TKT-M1-10`, `TKT-M6-02`, `TKT-M6-03`, `TKT-M6-04`
