# ADR-009 — Engine Distribution, Licensing and Packaging

**Status:** Proposed · **Date:** 2026-11-23

> **中文摘要**：在 `Vendor/7zz/<version>/` 固定版本地打包官方 macOS arm64 `7zz` 二进制及其许可证/声明文件，用 SHA-256 校验，作为嵌套代码签名并随 App 分发；不在 MVP 阶段从源码自行编译。需满足 LGPL 与 unRAR 许可证义务。方案待引擎 spike 验证。

## Context

ADR-004 selects the official `7zz` CLI. We must decide how it gets into the app and how we satisfy its license. Verified facts:
- 7-Zip 26.06 official downloads include macOS console archive `7z2600-mac.tar.xz` ([download](https://7-zip.org/download.html), [releases](https://github.com/ip7z/7zip/releases/)).
- License: mostly **GNU LGPL**; some code **LGPL + unRAR restriction**; some **BSD-3/2**; binary redistributions must reproduce the license information ([license.txt](https://www.7-zip.org/license.txt), [DOC/License.txt](https://github.com/ip7z/7zip/blob/main/DOC/License.txt)). The unRAR restriction forbids re-creating the RAR compression algorithm (no RAR creation).
- Homebrew packages `sevenzip` as `LGPL-2.1-or-later AND BSD-3-Clause`, supporting Apple Silicon ([formula](https://formulae.brew.sh/formula/sevenzip)).

## Decision Drivers

- Reproducible, offline-capable CI (no build-time network dependency).
- Supply-chain integrity (pin + checksum).
- License compliance for free redistribution.
- Correct nested code signing so a notarized app's helper is valid.
- Small repo size.

## Considered Options

1. **Vendor prebuilt official binary, pinned + checksummed (Proposed choice)**.
2. **Build 7zz from source in CI**: fully reproducible provenance, but slow, needs a build system, and version drift; heavier.
3. **Download at build time**: no repo bloat, but CI network dependency and supply-chain risk; no offline builds.
4. **Require user-installed 7zz / Homebrew**: unacceptable UX for a distributed app.
5. SwiftPM wrapper package: no canonical official one; rejected.

## Decision

- Store the official macOS arm64 `7zz` under **`Vendor/7zz/<version>/7zz`** with:
  - `LICENSE-7ZIP.txt` (verbatim from `DOC/License.txt`) and a `NOTICE.md` summarizing LGPL + unRAR terms and the upstream source URL.
  - `SHA256SUMS` pinned to the exact release; a CI/step script verifies the checksum before packaging.
- At bundle time, copy `7zz` into `Mac7Zip.app/Contents/Helpers/7zz`; set executable bit; **codesign the helper as nested code** (Developer ID, `--timestamp`, `-o runtime`) before signing the app; the app's `Info.plist`/entitlements must permit executing the helper (no JIT/library-validation relaxations unless required by the helper — verify in spike).
- Ship `LICENSE-7ZIP.txt` + `NOTICE.md` inside `Contents/Resources/` and reference them in the app's About/Licenses screen (M5) and repo `THIRD_PARTY_NOTICES.md`.
- Document source-availability for LGPL: link to the upstream 7-Zip source and note any modifications (none planned).
- The exact upstream artifact name/filename and arm64 contents are validated by the **engine packaging spike** (`TKT-M2-01`); if the official mac archive is universal or x64-only, fall back to building from source (option 2) — recorded as a Proposed contingency.

## Rationale

Vendoring a pinned, checksummed official binary is the best trade of reproducibility, supply-chain integrity, and CI simplicity, provided compliance artifacts ship with it. Building from source remains a documented fallback.

## Consequences

- Repo gains a ~1–2 MB binary; acceptable.
- Release signing must handle a nested executable (a known notarization failure source).
- Legal: must keep license text current with the pinned version.

## Risks / Trade-offs

- **UNVERIFIED**: exact arm64 contents of `7z2600-mac.tar.xz` (universal vs per-arch) — resolve in spike; contingency = build from source.
- Mismatch between bundled license text and binary version → automated check compares version string to `NOTICE`.
- unRAR restriction misread could imply RAR creation → explicitly disable RAR creation in UI/tests.

## Related

- Specs: `SPEC-REL`, `SPEC-AE`
- ADRs: ADR-004, ADR-010
- Tickets: `TKT-M2-01`, `TKT-M6-04`
