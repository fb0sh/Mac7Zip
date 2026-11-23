# ADR-008 — Archive Extraction Security Model

**Status:** Accepted (policy) / Proposed (numeric limits) · **Date:** 2026-11-23

> **中文摘要**：默认“失败即中止”的解压安全模型：解压前校验每个条目、解压中持续强制限制；拒绝绝对路径/`..` 穿越、符号/硬链接逃逸、设备/FIFO 等特殊文件、超限大小与异常膨胀比；使用受控暂存目录，失败不落地最终目录，并报告具体违规条目。

## Context

Archives are untrusted input. Classic attacks: path traversal (`../../etc/...`), absolute paths, symlink/hardlink escaping the destination, device/FIFO creation, and zip bombs (huge expansion ratio). Metadata can lie, so pre-validation alone is insufficient. The user approved fail-closed behavior (Round 2, Q5) with validation before and during extraction.

## Decision Drivers

- Never write outside the user-chosen destination.
- No silent partial extraction of unsafe content.
- Actionable errors naming offending entries.
- Works with 7zz's extraction model (we control the destination and post-verify).

## Considered Options

1. **Skip unsafe entries and continue (default)**: convenient, but silently produces incomplete output and risks users trusting it.
2. **Fail-closed: abort entire operation on any unsafe entry (chosen)**.
3. Trust 7zz's own protections: insufficient/undefined across formats.

## Decision

- **Pre-flight validation** of the entry list (`7zz l -slt`) before extraction:
  - Reject absolute entry paths and any `..` traversal after normalization.
  - Reject entries that canonicalize outside the destination root.
  - Reject symlink/hardlink entries whose target escapes the extraction root (and, in MVP, reject all links to be safe — Proposed).
  - Reject special files: device nodes, FIFOs, sockets.
  - Enforce **limits**: maximum total uncompressed size and maximum per-entry expansion ratio (conservative defaults; **Proposed** values in SPEC-SEC, e.g. total ≤ 4× available free space, ratio ≤ 100:1), reject encrypted-without-password where relevant.
- **Extraction into a controlled staging directory** under the app's temp area, then atomically move into the destination only on full success.
- **Post-extraction enforcement**: with `-bsp1` progress, monitor bytes written; abort if limits exceeded (metadata can be wrong). Re-validate that created symlinks/hardlinks point within root.
- **TOCTOU**: extract into a private staging dir the process controls; validate final paths immediately before move; never follow attacker-controlled symlinks during the move.
- **On any violation**: abort, delete staging contents, return `.unsafeEntry(paths:[...], reason:)`; never leave partial unsafe output in the destination.
- Limits are configurable with conservative defaults; unlimited is never the default.

## Rationale

Fail-closed is the only safe default for a tool that will open archives from the internet. Staging + atomic move prevents partial/escaped outputs and dramatically reduces TOCTOU exposure.

## Consequences

- Extraction requires free disk space ≥ staged size; report clearly if insufficient.
- Some legitimately unusual archives (e.g., symlink-heavy tarballs) are refused in MVP; a future opt-in "extract safe entries only" mode can be added.
- Engine adapter must parse listings and monitor progress bytes.

## Risks / Trade-offs

- Ratio limits can reject legitimate highly-compressible data → make configurable and document.
- Staging doubles peak disk usage for large archives → check free space first; offer direct-extract mode as a future opt-in with compensating checks.
- Symlink policy may break some real tarballs → documented limitation.

## Related

- Specs: `SPEC-SEC`, `SPEC-AE`
- ADRs: ADR-004, ADR-005, ADR-007
- Tickets: `TKT-M2-06`, `TKT-M2-07`, `TKT-M2-11`
