# M3 — Compression (MVP) — Tickets

**Milestone:** M3 · **Spec:** [SPEC-CW](../specs/compression.md) · **Status:** Planned

> **中文摘要**：M3 工单——创建压缩包核心命令、SwiftUI 压缩对话框、密码/加密、目标冲突处理、进度/取消与完成反馈、高级选项（P2）、往返集成测试。

---

## TKT-M3-01 — Create-archive core command + option mapping

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** `SevenZipEngine.createArchive` for 7z/ZIP; map `CompressionRequest` → 7zz argv; validate format support.
- **Implementation Notes:** `7zz a -t<fmt> -mx<level> [-p<pw>] -bsp1 ...`; write to temp then move; reject unsupported formats.
- **Dependencies:** TKT-M2-02.
- **Acceptance Criteria:** Creates valid 7z/ZIP from files/dirs; `7zz t` passes; unsupported → `.unsupportedFormat`.
- **Tests:** Unit argv mapping; integration create+test.
- **DoD:** CI green.
- **Related:** SPEC-CW · ADR-004, ADR-009

## TKT-M3-02 — Compression dialog (SwiftUI form) + validation

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Native form (name, location, format, level, password, advanced disclosure); validation gates Create.
- **Implementation Notes:** `.formStyle(.grouped)`; NSSavePanel for location; defaults 7z/normal.
- **Dependencies:** TKT-M3-01.
- **Acceptance Criteria:** AC-CW-1; invalid inputs disable Create with inline reason.
- **Tests:** ViewModel validation unit tests; UI smoke.
- **DoD:** CI green.
- **Related:** SPEC-CW · ADR-001

## TKT-M3-03 — Password/encryption + secure handling

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Password + confirm; 7z AES-256; ZIP AES-256 (verify in spike); never log/persist.
- **Implementation Notes:** Redact `-p` in diagnostics; if ZIP AES unsupported, disable with explanatory text.
- **Dependencies:** TKT-M3-01.
- **Acceptance Criteria:** AC-CW-4; logs contain no plaintext password.
- **Tests:** Encrypted round-trip; log redaction scan.
- **DoD:** CI green.
- **Related:** SPEC-CW, SPEC-SEC · ADR-008

## TKT-M3-04 — Target conflict + destination validation

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Replace / Keep Both / Cancel; preserve original until success; validate writable destination; refuse archive-inside-itself.
- **Implementation Notes:** `NSAlert` conflict; auto-suffix for Keep Both; atomic replace on success.
- **Dependencies:** TKT-M3-01.
- **Acceptance Criteria:** AC-CW-2; original untouched on Cancel; safe replace.
- **Tests:** Conflict-path integration tests.
- **DoD:** CI green.
- **Related:** SPEC-CW · ADR-004

## TKT-M3-05 — Compression progress/cancel + completion feedback

- **Priority:** P0 · **Type:** Feature · **Status:** Planned
- **Scope:** Run create via `TaskCenter`; progress/cancel; completion toast + Reveal in Finder.
- **Implementation Notes:** Reuse Tasks popover/status; clean temp on cancel.
- **Dependencies:** TKT-M3-01, TKT-M2-08.
- **Acceptance Criteria:** AC-CW-5; progress responsive; cancel cleans up.
- **Tests:** Cancellation integration.
- **DoD:** CI green.
- **Related:** SPEC-CW, SPEC-TM · ADR-005

## TKT-M3-06 — Advanced options (multi-volume, method, threads)

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Multi-volume (`-v`), method (LZMA2), thread count; advanced disclosure. Post-MVP.
- **Implementation Notes:** Keep defaults simple; advanced collapsed.
- **Dependencies:** TKT-M3-01.
- **Acceptance Criteria:** Options map to 7zz and round-trip; invalid combos disabled.
- **Tests:** Option mapping unit tests.
- **DoD:** CI green.
- **Related:** SPEC-CW · ADR-004

## TKT-M3-07 — Round-trip integration tests

- **Priority:** P0 · **Type:** Test · **Status:** Planned
- **Scope:** create→test→extract for 7z/ZIP; encrypted; conflict; cancel; failure paths.
- **Implementation Notes:** Deterministic fixtures; compare extracted trees.
- **Dependencies:** TKT-M3-01…05.
- **Acceptance Criteria:** All SPEC-CW acceptance scenarios covered.
- **Tests:** The tests themselves.
- **DoD:** CI green; no flaky.
- **Related:** SPEC-CW · ADR-010

## TKT-M3-08 — Advanced compression options (full parameter set)

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Background:** FR-CW-10; complements TKT-M3-06 (which covers multi-volume/method/threads).
- **Scope:** Remaining advanced fields: update mode, path mode, dictionary/word size, solid block size, memory-required estimate display, "delete source after", and "encrypt file names".
- **Implementation Notes:** Map each to 7zz switches; disable invalid combos; encrypt-file-names requires 7z; show memory estimate from engine.
- **Dependencies:** TKT-M3-01, TKT-M3-03.
- **Acceptance Criteria:** Each option maps and round-trips; invalid combos disabled; encrypt-file-names only for 7z.
- **Tests:** Option-mapping unit tests; round-trip integration.
- **DoD:** CI green.
- **Related:** SPEC-CW (FR-CW-10) · ADR-004, ADR-009
