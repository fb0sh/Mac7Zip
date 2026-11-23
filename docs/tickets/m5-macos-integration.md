# M5 — macOS Integration — Tickets

**Milestone:** M5 · **Epic:** EPIC-M5 · **Spec:** [SPEC-MI](../specs/macos-integration.md) · **Status:** Planned

> **中文摘要**：M5 工单——文件关联/Open With/文档打开、设置窗口、Quick Look、完成通知、关于与许可证、Finder 服务、窗口恢复/深链、集成测试与人工清单。全部可实施，遵循 SPEC-MI。

---

## TKT-M5-01 — Archive file associations + Open With + document open

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Declare `CFBundleDocumentTypes`/UTTypes for 7z/zip/tar.gz; handle open-document/URL events → browse archive.
- **Implementation Notes:** Info.plist keys; route via app delegate/`.onOpenURL`; cold-start open.
- **Dependencies:** TKT-M2-05.
- **Acceptance Criteria:** AC-MI-1; double-click from Finder opens and browses.
- **Tests:** Plist snapshot; open-handler integration on temp archive.
- **DoD:** CI green; manual Finder check.
- **Related:** SPEC-MI · ADR-010

## TKT-M5-02 — Settings window (activation, limits, defaults)

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** SwiftUI `Settings`: archive activation (Open/Extract), default extract destination/subfolder, extraction limits (size/ratio), default format.
- **Implementation Notes:** Persist via `AppSettings`; validate numeric limits; full version of `TKT-M2-13` minimal preference.
- **Dependencies:** TKT-M2-13.
- **Acceptance Criteria:** AC-MI-3; changes persist and affect subsequent operations.
- **Tests:** Settings persistence + validation tests.
- **DoD:** CI green.
- **Related:** SPEC-MI · ADR-007

## TKT-M5-03 — Quick Look preview for archive entries

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Preview selected entry via secure temp extraction + Quick Look panel; cleanup after.
- **Implementation Notes:** Extract single entry to temp (ADR-008), present `QLPreviewPanel`, delete on dismiss.
- **Dependencies:** TKT-M2-07.
- **Acceptance Criteria:** AC-MI-2; temp cleaned; unsupported types handled.
- **Tests:** Temp cleanup test; manual preview.
- **DoD:** CI green; manual verified.
- **Related:** SPEC-MI, SPEC-SEC · ADR-008

## TKT-M5-04 — Completion notifications

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Opt-in user notifications on task completion/failure.
- **Implementation Notes:** `UNUserNotificationCenter`; request once; respect denied silently.
- **Dependencies:** TKT-M2-08.
- **Acceptance Criteria:** AC-MI-4.
- **Tests:** Authorization-state unit tests.
- **DoD:** CI green.
- **Related:** SPEC-MI · ADR-005

## TKT-M5-05 — About + Licenses screen

- **Priority:** P1 · **Type:** Feature · **Status:** Planned
- **Scope:** Show app version, 7-Zip `LICENSE-7ZIP.txt` + `NOTICE.md` (LGPL/unRAR), third-party notices.
- **Implementation Notes:** Bundle notices in Resources; render in About/Settings.
- **Dependencies:** TKT-M2-01.
- **Acceptance Criteria:** AC-MI-5; notices present and readable.
- **Tests:** Resource-presence test; UI smoke.
- **DoD:** CI green.
- **Related:** SPEC-MI, SPEC-REL · ADR-009

## TKT-M5-06 — Finder Services / context actions

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Finder Services/context actions: Open archive, Extract files…, Extract here, Extract to `<name>/`, Test, Add to archive…, Add to `<name>.7z`/`.zip`, CRC SHA; email deferred.
- **Implementation Notes:** `NSServices` provider; route to extraction/compression engines; secure defaults.
- **Dependencies:** TKT-M2-07, TKT-M3-01.
- **Acceptance Criteria:** AC-MI-6; service actions work on selected Finder files.
- **Tests:** Service action unit tests; manual Finder check.
- **DoD:** CI green; manual verified.
- **Related:** SPEC-MI · ADR-009

## TKT-M5-07 — Window restoration + deep links

- **Priority:** P2 · **Type:** Feature · **Status:** Planned
- **Scope:** Restore last location; open a specific archive via URL/deep link; recent documents optional.
- **Implementation Notes:** Persist last `BrowserLocation.real`; handle URL scheme + document open.
- **Dependencies:** TKT-M5-01.
- **Acceptance Criteria:** Relaunch restores location; deep link opens archive.
- **Tests:** Restoration state tests.
- **DoD:** CI green.
- **Related:** SPEC-MI · ADR-003

## TKT-M5-08 — Integration tests + manual acceptance checklist

- **Priority:** P1 · **Type:** Test · **Status:** Planned
- **Scope:** Automate plist/open-handler/settings; write manual checklist for Finder/Quick Look/notifications/Services/Liquid Glass.
- **Implementation Notes:** CI covers non-GUI; manual checklist executed on real Mac before release.
- **Dependencies:** TKT-M5-01…07.
- **Acceptance Criteria:** All SPEC-MI ACs covered by automated or documented manual steps.
- **Tests:** The tests + checklist.
- **DoD:** CI green; checklist signed off.
- **Related:** SPEC-MI · ADR-010
