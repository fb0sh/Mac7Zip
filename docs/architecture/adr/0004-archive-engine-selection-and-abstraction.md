# ADR-004 — Archive Engine Selection and Abstraction

**Status:** Accepted (engine choice) / Proposed (exact format matrix details) · **Date:** 2026-11-23

> **中文摘要**：选用官方 `7zz` 命令行作为压缩引擎，通过 `ArchiveEngine` 协议抽象，与 UI 完全解耦。MVP 支持创建 7z/ZIP、读取/解压 7z/ZIP/TAR/GZIP/BZIP2/XZ 及只读解压 RAR；不支持创建 RAR。

## Context

Mac7Zip's core value is archive capability. Phase 0 ships only an `ArchiveEngine` protocol stub (`Sources/Archive/ArchiveEngine.swift`) with no implementation. We must choose the underlying engine and lock the boundary so UI, task management, and security policy can be built once and reused.

Verified upstream facts:
- Official **7-Zip 26.06** (2026-11-06) provides console builds for Linux/macOS, including a macOS archive (`7z2600-mac.tar.xz`), distributed via [7-zip.org/download.html](https://7-zip.org/download.html) and [github.com/ip7z/7zip/releases](https://github.com/ip7z/7zip/releases/).
- Licensing: mostly **GNU LGPL**, some code **LGPL + unRAR restriction**, some **BSD-3/BSD-2**; binary redistributions must reproduce the license information ([7-zip.org/license.txt](https://www.7-zip.org/license.txt), [DOC/License.txt](https://github.com/ip7z/7zip/blob/main/DOC/License.txt)).
- Supported formats: creation for **7z, BZIP2, GZIP, TAR, WIM, XZ, ZIP**; extraction for a much broader set including **RAR** ([7-Zip formats manual](https://7zip.bugaco.com/7zip/MANUAL/general/formats.htm), [7-zip.org](https://7-zip.org/)).
- The unRAR restriction permits handling RAR archives but **not re-creating the RAR compression algorithm** → RAR creation is unsupported.

## Decision Drivers

- Broadest real-world format coverage and first-class 7z (LZMA/LZMA2) compression.
- 7z AES-256 encryption support.
- Process isolation for parsing untrusted archives.
- Licensing we can satisfy for free redistribution (LGPL) with no royalty.
- Minimal new third-party code in-process.

## Considered Options

1. **Official `7zz` subprocess (chosen)**: broadest formats, encryption, process isolation; cost = CLI parsing, process lifecycle, LGPL/unRAR obligations.
2. **`libarchive` (in-process)**: permissive license, good common formats; weaker 7z write/encryption, in-process parsing of untrusted data raises crash/exploit blast radius.
3. **XADMaster / other Obj-C libs**: less maintained, narrower, still in-process.
4. **Custom engine**: unacceptable scope and security risk.

## Decision

- Implement **`SevenZipEngine: ArchiveEngine`** that drives a **bundled `7zz` binary** as a subprocess (ADR-009 defines distribution/versioning).
- Keep the existing `ArchiveEngine` protocol as the only surface UI/State use; no UI type leaks into the engine.
- **MVP format matrix** (P0), with everything else deferred (P2, documented in SPEC-AE):

| Capability | 7z | ZIP | TAR | GZIP | BZIP2 | XZ | RAR |
|---|---|---|---|---|---|---|---|
| List / read | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (read-only) |
| Extract all / selected | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (read-only, unRAR terms) |
| Create | ✅ | ✅ | ➖ later | ➖ later | ➖ later | ➖ later | ❌ unsupported |
| Update existing | ✅ | ✅ | ➖ later | — | — | — | ❌ |
| Encrypt on create | ✅ AES-256 | ⚠️ verify in spike | — | — | — | — | — |

- Normalized result/error types: success, warning (exit 1), fatal (exit 2), command-line error (7), out-of-memory (8), user-stopped (255) — see [exit codes](https://7zip.bugaco.com/7zip/MANUAL/cmdline/exit_codes.htm).

## Rationale

Subprocess isolation is the right security posture for untrusted archives and gives the widest format coverage with least in-process attack surface. 7zz is the reference implementation of 7z and supports the encryption and formats users expect.

## Consequences

- All archive operations are asynchronous and cancellable via `TaskCenter` (ADR-005).
- The engine adapter must parse `7zz` text output; parsing is isolated and unit-tested (SPEC-AE).
- Format-matrix cells marked ⚠️/➖ are **Proposed** and resolved by the engine spike (`TKT-M2-02`/`TKT-M2-03`).

## Risks / Trade-offs

- CLI output parsing brittleness across 7zz versions → pin version and test against fixtures.
- ZIP AES-256 creation support must be verified; if unsupported, UI must state it.
- LGPL/unRAR obligations require shipping license text/notices (ADR-009).

## Related

- Specs: `SPEC-AE`, `SPEC-CW`
- ADRs: ADR-005, ADR-009
- Tickets: `TKT-M2-02`, `TKT-M2-03`
