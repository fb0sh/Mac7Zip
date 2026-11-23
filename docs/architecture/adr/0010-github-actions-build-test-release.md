# ADR-010 — GitHub Actions Build, Test and Release Strategy

**Status:** Accepted (build/test) / Proposed (notarization gating) · **Date:** 2026-11-23

> **中文摘要**：`build.yml` 保持无签名、无密钥的每次 PR/Push CI（编译、静态检查、单测、集成测试、架构与依赖检查、产物上传）；`release.yml` 由 `v*` 标签触发，使用受保护的 `release` Environment 注入 Developer ID 与 notarytool 凭据，完成签名/公证/装订/DMG+ZIP 并校验后再发布。XCUITest 冒烟作为早期基础设施 spike。

## Context

Development happens on Windows/Linux; GitHub Actions is the primary macOS build/verify environment. Phase 0 already has a working `build.yml` on `macos-26` (GA since 2026-02-26, native Apple Silicon + x64, default Xcode 26.x — [changelog](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/), [runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)). Distribution is direct (GitHub Releases); Developer Account is unconfirmed.

## Decision Drivers

- Never block feature development on signing credentials.
- Reproducible unsigned dev builds.
- Layered verification: static → unit → integration → build/arch → UI smoke.
- Clear, actionable failures.
- Integrity before publishing a release.

## Considered Options

1. Single workflow with conditional signing: fewer files, but risks leaking secrets into PR context and tangling concerns.
2. **Two workflows: `build.yml` (unsigned, secret-free) + `release.yml` (tag, protected env) (chosen)**.
3. Fully manual release: not reproducible, error-prone.

## Decision

**`build.yml`** (every push/PR/dispatch, no secrets):
- Select + assert Xcode 26.x; install XcodeGen; generate project.
- `swift-format lint` and `SwiftLint` as **non-blocking** (pinned versions, explicit config).
- Debug compile; **host-free unit tests**; archive **integration tests** (round-trip, corruption, wrong password, cancel, traversal).
- Release build; **`lipo -info` arch check** (arm64); `otool -L` dependency audit.
- Package + upload unsigned `.app` ZIP artifact (existing behavior).
- Upload logs/results on failure.

**`release.yml`** (on `v*` tags; protected `release` Environment with required reviewer):
- Import Developer ID cert from secrets; sign app + nested `7zz` helper (`--timestamp`, `-o runtime`).
- `notarytool submit --wait`, `stapler staple`, `spctl -a -vv` and `codesign --verify --deep --strict` verification.
- Build DMG (`hdiutil`) and ZIP; sign/notarize/verify both; only then publish GitHub Release assets.
- If credentials are absent, the job **fails clearly** with actionable diagnostics and never publishes an unsigned artifact as official.
- Verify signatures, Hardened Runtime, notarization, and artifact contents **before** publishing.

**GUI verification:** add an `XCUITest` smoke target spiked against `macos-26` (launch, browse Home, switch sidebar, sort, select) with screenshot/log artifacts; treat CI GUI support as an **early infrastructure spike** (`TKT-M1-10`/`SPK-GUI`), and keep a manual acceptance checklist for visual/Liquid Glass fidelity (SPEC-REL).

## Rationale

Separating unsigned CI from signed release is the standard secure pattern: secrets never touch PR builds, and feature work never waits on credentials. Layered checks match the no-local-Mac constraint.

## Consequences

- Two workflow files; shared steps may be factored into a composite action later.
- `release.yml` contains a credentials-gated path that may be dormant until the account exists (documented no-op/fail-clear).
- Integration tests need sample archives checked into `Tests/Fixtures/`.

## Risks / Trade-offs

- CI GUI tests can be flaky/headless-limited → spike first; don't gate features on them initially.
- Notarization duration/varisity in CI → `--wait` with timeout; retry policy.
- Lint promotion to blocking could stall work → keep non-blocking until baseline clean.

## Related

- Specs: `SPEC-REL`
- ADRs: ADR-009
- Tickets: `TKT-M1-10`, `TKT-M6-02`, `TKT-M6-03`
