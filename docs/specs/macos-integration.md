# SPEC-MI — macOS Integration (M5)

**Status:** Accepted · **Milestone:** M5 · **Last updated:** 2026-11-23

> **中文摘要**：M5 macOS 集成规格——压缩包文件关联与 Open With、Quick Look 预览、任务完成通知、设置窗口（激活偏好/限制/默认格式）、关于与许可证、Finder 服务/右键动作、窗口恢复与深链。

## 1. Overview

Makes Mac7Zip a first-class macOS citizen: open archives from Finder/Dock, preview entries, notify on completion, expose settings/licenses, and provide Finder services — while preserving archive read-only semantics and security.

## 2. Goals

- Open archives from Finder via association/Open With and handle document-open events.
- Native settings, notifications, Quick Look, and license disclosure.
- Finder service actions mirroring the 7-Zip operation model.

## 3. Non-goals

- Mac App Store distribution / sandbox (see SPEC-SEC appendix).
- Share extension / Shortcuts app integration (P2).
- Mail/email sending actions.
- Spotlight importer / metadata indexing (future).

## 4. User Scenarios

- **S1**: Double-click a `.7z` in Finder → opens in Mac7Zip and browses it.
- **S2**: Right-click a `.zip` → Open With → Mac7Zip.
- **S3**: Select an entry in archive → spacebar Quick Look preview.
- **S4**: Task completes → system notification.
- **S5**: Settings → toggle archive activation (Open/Extract), set extraction limits/default format.
- **S6**: About → Licenses shows 7-Zip LGPL/unRAR notices.
- **S7**: Finder Services → Extract here / Add to archive.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-MI-01 | Declare document types/UTTypes for 7z, zip, tar.gz and handle open-document/URL events. |
| FR-MI-02 | "Open With" supported via document types; opening an archive browses it. |
| FR-MI-03 | Quick Look preview for a selected archive entry via secure temp extraction with cleanup. |
| FR-MI-04 | Completion/failure notifications via `UNUserNotificationCenter` (opt-in). |
| FR-MI-05 | Settings scene: archive activation (Open/Extract), default extract destination, extraction limits, default format. |
| FR-MI-06 | About + Licenses screen surfacing `LICENSE-7ZIP.txt` and `NOTICE.md` (ADR-009 compliance). |
| FR-MI-07 | Finder Services: Open archive, Extract files…, Extract here, Extract to `<name>/`, Test, Add to archive…, Add to `<name>.7z`/`.zip`, CRC SHA (email deferred). |
| FR-MI-08 | Window restoration (last location) and deep-link open of a specific archive. |

## 6. UX / Interaction Design

- Settings uses native `Settings` scene with grouped tabs.
- Notifications respect system permission; never spam.
- Quick Look uses the standard panel; temp files deleted after.
- Licenses reachable from About and Settings.

## 7. Technical Design

- `Info.plist`: `CFBundleDocumentTypes`, `UTImportedTypeDeclarations`/`CFBundleURLTypes`.
- `NSApplicationDelegate`/`.onOpenURL`/`.handlesExternalEvents` route document opens to a new/again `BrowserStore`.
- Quick Look: `QLPreviewingController`-style or write to temp + `QLPreviewPanel`.
- Notifications: request authorization; post on task completion.
- Services: `NSServices` provider / AppKit `NSResponder` services.
- Settings persisted in `UserDefaults`.

## 8. Data Models / Interfaces

```swift
enum ArchiveActivation: String, Codable, Sendable { case open, extract }
struct AppSettings: Codable, Sendable {
    var archiveActivation: ArchiveActivation = .open
    var defaultExtractToSubfolder: Bool = true
    var defaultFormat: ArchiveFormat = .sevenZip
    var extractionLimits: ExtractionLimits = .init()
}
```

## 9. Error Handling

- Open-failure (corrupt/unsupported) → alert with diagnostic.
- Quick Look extraction failure → non-blocking message.
- Notification permission denied → silent, no repeated prompts.

## 10. Performance Requirements

- Document open→list first paint < 1.5 s for typical archives.
- Quick Look preview ≥ 90% of entry types (files) via temp extraction; < 2 s for small files.
- Settings open < 150 ms.

## 11. Security Requirements

- Quick Look temp extraction obeys ADR-008 (fail-closed) and cleans up.
- Never auto-extract to the user's folder without an explicit action.
- License notices shipped and visible (LGPL/unRAR compliance).

## 12. Acceptance Criteria

- **AC-MI-1** — Given a `.7z` in Finder, When Open With → Mac7Zip, Then it opens and browses the archive.
- **AC-MI-2** — Given an entry selected, When Quick Look invoked, Then a preview appears and temp files are removed after.
- **AC-MI-3** — Given archiveActivation = extract, When double-clicking an archive in the file list, Then it extracts to `<name>/`.
- **AC-MI-4** — Given a completed task with notifications enabled, Then a notification is delivered.
- **AC-MI-5** — Given About → Licenses, Then the 7-Zip LGPL and unRAR notices are shown.
- **AC-MI-6** — Given a Finder Service "Extract here", Then the archive extracts to the enclosing folder.

## 13. Test Strategy

- Unit: settings persistence, activation routing, UTType declarations (plist snapshot).
- Integration: document-open handler on temp archive.
- Manual (real Mac): Finder Open With, Quick Look, notifications, Services.

## 14. Dependencies

- M1–M3 complete; SPEC-AB/AE; ADR-009 (licenses), ADR-010.

## 15. Related ADRs / Tickets

- ADRs: ADR-001, ADR-007, ADR-009, ADR-010
- Tickets: `TKT-M5-01` … `TKT-M5-08`
