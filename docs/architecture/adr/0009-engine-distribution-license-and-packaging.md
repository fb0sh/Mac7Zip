# ADR-009 — Engine Distribution, Licensing and Packaging

**Status:** Accepted (version pinned & assets verified) · **Signing/notarization: Proposed** · **Date:** 2026-11-23

> **中文摘要**：锁定官方 7-Zip **26.06**，使用其官方 macOS 资产：`7z2606-mac.tar.xz`（arm64，sha256 `b6f179…85dd`）与 `7z2606-mac-x64.tar.xz`（x86_64，sha256 `3af68b…5586`），已下载校验并确认 Mach-O 架构。内置 `7zz` + `License.txt`/`readme.txt`，SHA-256 校验，嵌套代码签名；不做 RAR 创建。运行时行为需在 macOS CI 验证。

## Context

ADR-004 selects the official `7zz` CLI. We must pin an exact version, prove which official asset is which architecture, satisfy licensing, and package/sign the helper. Development is on Linux/Windows, so binary *architectures* can be verified here but *runtime execution* must be verified on macOS CI.

## Verified upstream facts (2026-11-23)

Source: official release `ip7z/7zip` tag **26.06** (assets fetched via `gh release download`; SHA-256 verified locally; architecture checked with `file`).

| Asset | Size (bytes) | SHA-256 | Verified architecture | Contents |
|---|---|---|---|---|
| `7z2606-mac.tar.xz` | 965,712 | `b6f17920b4240940461dac8ef4009891881ac44d2a5ead625ede2ec8472185dd` | **Mach-O 64-bit arm64** | `7zz`, `License.txt`, `readme.txt`, `History.txt`, `MANUAL/` |
| `7z2606-mac-x64.tar.xz` | 1,025,228 | `3af68b124052da7fc2a246c96b0bea6a68bfee389baa788f4cead1a133445586` | **Mach-O 64-bit x86_64** | `7zz`, `License.txt`, `readme.txt`, `History.txt`, `MANUAL/` |

- License: GNU LGPL (some code LGPL + unRAR restriction, some BSD); binary redistributions must reproduce license info — `License.txt` from the archive ([7-zip.org/license.txt](https://www.7-zip.org/license.txt)).
- unRAR restriction permits handling RAR but **not creating RAR**.
- **Not verified here:** runtime execution, codesign validity on macOS → validated in `TKT-M2-01` / macOS CI.

## Decision Drivers

- Reproducible, offline-capable builds; supply-chain integrity via pin + checksum.
- Correct architecture selection (arm64 MVP; x86_64 for Universal in M6).
- License compliance for free redistribution.
- Nested code signing compatible with notarized app.
- Small repo footprint.

## Considered Options

1. **Vendor pinned official binaries + checksums (chosen)** — arm64 now, add x64 for Universal.
2. Build 7zz from source in CI (reproducible provenance, slower/heavier).
3. Download at build time (network/supply-chain risk).
4. Require user-installed 7zz (unacceptable UX).

## Decision

- Pin **7-Zip 26.06**. Store under `Vendor/7zz/26.06/arm64/7zz` and `Vendor/7zz/26.06/x86_64/7zz`, each with `License.txt`, `readme.txt`, and a `SHA256SUMS` pinned to the hashes above.
- CI packaging step verifies `sha256sum` before copying to `Mac7Zip.app/Contents/Helpers/7zz` (or per-arch helper for Universal).
- Ship `License.txt`/`THIRD_PARTY_NOTICES.md` in `Contents/Resources/`; surface in About/Licenses (`TKT-M5-05`).
- **Nested code signing:** sign the helper with Developer ID (`--timestamp`, `-o runtime`) before signing the app; verify `codesign --verify --deep --strict` and notarize. No JIT/library-validation relaxations unless proven necessary by the helper (verify in `TKT-M6-04`).
- **Never enable RAR creation** in UI/engine.
- Fallback if a verified asset is unsuitable: build from source (option 2), recorded as a new ADR.

## Rationale

Vendoring two pinned, checksummed official binaries unblocks arm64 now and Universal later with no build-time network dependency, provided license artifacts ship alongside.

## Consequences

- Repo gains ~2 MB of binaries; acceptable.
- Release signing must handle nested executables (classic notarization failure source).
- License text must stay in sync with pinned version (automated check).

## Risks / Trade-offs

- Runtime behavior of bundled 7zz untested locally → validated on macOS CI (`TKT-M2-01`).
- Codesign deeper options (`disable-library-validation`) may be required → verify; avoid unless needed.
- unRAR restriction could be misread → explicit "no RAR creation" test.

## Related

- Specs: `SPEC-REL`, `SPEC-AE`
- ADRs: ADR-004, ADR-005, ADR-010
- Tickets: `TKT-M2-01`, `TKT-M6-03`, `TKT-M6-04`
