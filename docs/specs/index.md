# Specifications Index

**Status:** Living · **Last updated:** 2026-11-23

> **中文摘要**：本索引列出所有功能规格（SPEC-FM/AE/AB/CW/TM/SEC/REL），并说明它们对应的里程碑与上游 ADR。每个 Spec 都是可直接实施、可测试的需求来源。

| Spec | Title | Milestone(s) | Upstream ADRs |
|---|---|---|---|
| [SPEC-FM](file-manager.md) | File Manager (browsing, navigation, selection, basic file ops) | M1 (MVP), M4 (enhancements) | ADR-001, ADR-002, ADR-003, ADR-007 |
| [SPEC-AE](archive-engine.md) | Archive Engine (7zz adapter, formats, extraction, test) | M2 (MVP) | ADR-004, ADR-005, ADR-008, ADR-009 |
| [SPEC-AB](archive-browser.md) | Archive Browser (virtual FS browsing inside archives) | M2 (MVP read-only), M5 | ADR-006, ADR-003 |
| [SPEC-CW](compression.md) | Compression Workflow (create ZIP/7z) | M3 (MVP) | ADR-004, ADR-005, ADR-009 |
| [SPEC-TM](task-management.md) | Background Task Management & progress/cancel | M2 (MVP), M3 | ADR-005 |
| [SPEC-SEC](security.md) | Security Model (access, extraction safety, future sandbox) | M1, M2, M5 | ADR-007, ADR-008 |
| [SPEC-REL](release.md) | CI, Build, Signing, Notarization & Release | M1, M6 | ADR-009, ADR-010 |

## Conventions

- Requirements are numbered (`FR-<AREA>-nn`) and are testable.
- Acceptance criteria use **Given / When / Then**.
- Each spec names explicit Non-goals so scope does not creep.
- Status values and ID scheme are defined in [`../architecture/overview.md`](../architecture/overview.md).
