# EPIC-M5 — macOS Integration

**Milestone:** M5 · **Priority:** P1 · **Status:** Planned · **Specs:** [SPEC-AB](../specs/archive-browser.md), [SPEC-REL](../specs/release.md)

> **中文摘要**：M5 Epic——把 Mac7Zip 融入 macOS：文件关联与 Open With、Quick Look 预览、通知、设置窗口、关于/许可证界面、Finder 服务菜单集成。

## Objective

Make Mac7Zip feel native and integrated: open archives from Finder/Dock, preview entries, notify on task completion, expose settings and licenses, and support system integrations — without violating the read-only archive semantics.

## Scope & Ticket breakdown (epic-level)

| ID | Title | Pri | Notes |
|---|---|---|---|
| TKT-M5-01 | Archive file associations + Open With | P1 | Declare `CFBundleDocumentTypes`/`UTType` for 7z/zip/tar.gz; open archive from Finder. |
| TKT-M5-02 | Settings window (general, security limits, defaults) | P1 | SwiftUI `Settings` scene; configure extraction limits, default format. |
| TKT-M5-03 | Quick Look preview for archive entries | P2 | Preview selected file from archive (extract-to-temp + QuickLook). |
| TKT-M5-04 | Completion notifications | P2 | `UNUserNotificationCenter` on task completion/failure. |
| TKT-M5-05 | About + Licenses screen (7-Zip LGPL/unRAR notices) | P1 | Surface `LICENSE-7ZIP.txt`/`NOTICE.md` (ADR-009 compliance). |
| TKT-M5-06 | Finder services / share integration | P2 | Finder Services/context actions: Open archive, Extract files…, Extract here, Extract to `<name>/`, Test, Add to archive…, Add to `<name>.7z`/`.zip`, CRC SHA; email actions deferred. |
| TKT-M5-07 | Deep links / window restoration | P2 | Restore last location; open specific archive via URL. |

## Acceptance Criteria (epic-level)

- **AC-M5-1** — Given a `.7z` in Finder, When "Open With → Mac7Zip", Then the app opens and browses the archive.
- **AC-M5-2** — Given the Settings window, When changing extraction limits, Then subsequent extractions enforce them.
- **AC-M5-3** — Given an archive entry selected, When Quick Look invoked, Then a preview appears without extracting unattended to the user's folder.
- **AC-M5-4** — Given a completed task, When enabled, Then a system notification is delivered.
- **AC-M5-5** — Given About/Licenses, Then the 7-Zip license and unRAR notice are visible.

## Dependencies

- M1–M3 complete; SPEC-AE/SPEC-AB; ADR-007/009.

## Risks

- File associations/launch-on-document require correct Info.plist/UTType and testing on a real Mac; CI can only partially verify.
- Quick Look temp extraction must respect security + cleanup.
