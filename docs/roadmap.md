# Mac7Zip — Development Roadmap

**Status:** Living · **Last updated:** 2026-11-23

> **中文摘要**：路线图——按 M1–M6 里程碑组织，给出交付物、依赖、退出标准、风险与阻塞项，并标注关键路径与可并行轨道。MVP = M1–M3（浏览→打开/解压→压缩）。

## 0. Guiding order (re-evaluated)

The user's suggested ordering is adopted with one refinement: because the MVP is **archive-centric**, the minimal file browser (M1) is trimmed to what archive work needs (browse/nav/sort/select + new-folder/rename/delete) and heavy file ops move to M4. This shortens time-to-value and reduces risk before the engine exists.

Priority: **stability → browser core → archive read/extract → compression → tasks/cancel → integration → advanced file ops → release hardening.**

## Milestones

### M1 — File Browser Core
- **Deliverables:** Provider/Store/FileAccess refactor; performant list; navigation/history; selection/sort/status; new folder/rename/delete; load/error states; shortcuts/context menus; tests; CI hardening + GUI spike.
- **Dependencies:** none.
- **Exit criteria:** All M1 acceptance criteria pass; 19+ tests green on `macos-26`; 10k-entry perf budget met; no `FileManager` in UI/State.
- **Risks:** refactor churn; mitigate with TKT-M1-01 regression tests first.

### M2 — Archive Read & Extract
- **Deliverables:** Bundled 7zz (pinned/licensed); engine runner + parsers; read-only archive provider; enter/navigate archives; SecurityValidator; extract all/selected; TaskCenter + progress/cancel; integrity test + password; security/integration tests.
- **Dependencies:** M1 (provider/store), TKT-M2-01 (packaging spike).
- **Exit criteria:** Open/browse/extract 7z/ZIP (and read TAR/GZIP/BZIP2/XZ/RAR) on `macos-26`; fail-closed security suite passes; 100k-entry list budget met; cancellation leaves no temp/orphans.
- **Risks:** 7zz arm64 artifact/licensing (ADR-009 UNVERIFIED); progress grammar; notarization-ready helper signing later.
- **Blockers:** none for read/extract (dev ad-hoc signing).

### M3 — Compression
- **Deliverables:** create 7z/ZIP; native dialog; encryption; conflict handling; progress/cancel; round-trip tests.
- **Dependencies:** M2 engine + TaskCenter.
- **Exit criteria:** SPEC-CW acceptance passes; encrypted 7z round-trip; cancellation cleanup verified.
- **Risks:** ZIP AES-256 creation support (Proposed; verify spike).

### M4 — File-Management Enhancements (post-MVP)
- **Deliverables:** copy/move, conflict UI, drag-drop, favourites, optional dual-pane, metadata, tests.
- **Dependencies:** M1 services; M2 TaskCenter.
- **Exit criteria:** EPIC-M4 ACs pass.
- **Risks:** network-volume/permissions edge cases; dual-pane complexity.

### M5 — macOS Integration
- **Deliverables:** file associations/Open With, settings, Quick Look, notifications, About/Licenses, Finder services.
- **Dependencies:** M1–M3; SPEC-AB/REL.
- **Exit criteria:** EPIC-M5 ACs pass (some require real-Mac manual verification).
- **Risks:** Info.plist/UTType correctness; Quick Look temp safety.

### M6 — Performance, Security & Release Hardening
- **Deliverables:** perf/memory tuning; malicious-archive suite; Universal; signing+notarization; DMG; GitHub Releases automation; expanded UI tests; release docs.
- **Dependencies:** M1–M5; **Apple Developer account**.
- **Exit criteria:** EPIC-M6 ACs; notarized universal DMG+ZIP published and verified.
- **Risks / Blockers:** Developer ID credentials (unconfirmed) block M6-04/05; notarized nested helper; universal build time.

## Critical path

`M1-01 → M2-01 → M2-02 → M2-03 → M2-04/05/06 → M2-07/08/09 → M3-01 → M3-02/04/05 → M6-04 → M6-05`

Everything else (M1 UI polish, M4, M5, docs) is off the critical path and parallelizable.

## Parallel tracks

- **A ✓ UI/State:** M1-02/03/04/07/08 after M1-01.
- **B ✓ Engine:** serial M2-01→02→03; M2-06 after M2-03.
- **C ✓ Tasks/UI:** M2-08/09 parallel with M2-04/05 once M2-02 lands.
- **D ✓ Compression:** M3 after engine; M3-06 (P2) flexible.
- **E ✓ CI:** M1-10 from day one; M6 automation later.
- **F ✓ Integration/docs:** M5 + notice docs can progress with M4.

## MVP definition of done (M1–M3)

Browse real dirs → open/navigate ZIP/7z → extract all/selected → create ZIP/7z → progress/cancel/errors — all green on `macos-26` CI, with fail-closed security for unsafe archives.

## Recommended first executable ticket

**`TKT-M1-01` — Foundation refactor** (see [M1 tickets](tickets/m1-file-browser-core.md#tkt-m1-01--foundation-refactor-filesystemprovider--browserstore--fileaccess)). It unblocks all UI and engine work, converts tests to host-free (faster CI), and establishes the provider/location seam that M2 depends on. Nothing else should start before it merges.
