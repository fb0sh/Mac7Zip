# Manual macOS Acceptance Checks

**Status:** Living · **Updated:** 2026-11-23

> **中文摘要**：CI 无法验证的、必须在真实 Mac 上人工确认的项目清单。每项记录所属票、状态与验证方式。CI 通过**不等于**这些项通过。

CI (`macos-26`) 能验证：编译、单元/集成测试、架构、依赖、打包、以及（后续）7zz 执行。
以下项目**必须**在真机上人工验收。

## Open items

| # | Check | Ticket | How to verify | Status |
|---|---|---|---|---|
| 1 | VoiceOver announces file name/size/kind per row; all actions keyboard-reachable | TKT-M1-12 (#57) | Accessibility Inspector + VoiceOver (⌘F5) | Not verified |
| 2 | Liquid Glass / macOS 26 visual fidelity, light & dark mode | TKT-M1-01…12 | Visual review | Not verified |
| 3 | Drag & drop behaviour (archive → Finder) | TKT-M2-12 (#23) | Manual drag | Not run (M4) |
| 4 | Quick Look preview of archive entry | TKT-M5-03 (#42) | Spacebar on entry | Not run (M5) |
| 5 | Finder Open With / document association | TKT-M5-01 (#40) | Finder double-click | Not run (M5) |
| 6 | Notifications delivery | TKT-M5-04 (#43) | Complete a task | Not run (M5) |
| 7 | XCUITest GUI smoke reliability | TKT-M6-06 (#53) | CI UI test run | Not run |
| 8 | Signed + notarized artifact launches under Gatekeeper | TKT-M6-04/05 (#51/#52) | `spctl -a -vv` on a clean Mac | Blocked: no Apple Developer credentials |

## Rule

Never mark an item verified without performing it. CI green is a *different* claim.

## Drag-out to Finder (TKT-M4-09) / drag-in (TKT-M4-03)
- [ ] Open an archive, select a file, drag to Finder Desktop → file appears and is intact.
- [ ] Select multiple archive entries, drag to a Finder folder → all appear.
- [ ] Drag a real file row to Finder → normal move/copy.
- [ ] Drag from Finder into the file list → copies (or moves with ⌘) into the current folder.
- [ ] Cancel/drop-outside → no files written, no temp leaks.

## Favourites & dual-pane (TKT-M4-04 / M4-05)
- [ ] Sidebar shows Favourites + System; "Add Current Folder" adds and persists across relaunch.
- [ ] Right-click a favourite → Remove; reopening the app shows the updated list.
- [ ] Toggle dual-pane: two independent panes; navigation in one doesn't affect the other.
- [ ] Active-pane highlight follows clicks; toggling off returns to a single pane.

## Settings & double-click (TKT-M5-02) / restoration (M5-07)
- [ ] Settings ▸ Archives: switching to "Extract" makes double-clicking an archive create a sibling `<name>/` folder.
- [ ] Switching back to "Open" makes double-click browse the archive.
- [ ] Limits tab persists values and rejects 0; reset restores defaults.
- [ ] Relaunch restores the last browsed folder when enabled; disabled starts at Home.

## File associations / notifications / About (M5-01, M5-04, M5-05)
- [ ] Double-click a .7z/.zip in Finder → Mac7Zip opens and browses it (cold + warm launch).
- [ ] "Open With → Mac7Zip" works; `mac7zip://` URL opens the app.
- [ ] With notifications enabled, finishing a task posts a banner; with permission denied, none appears and nothing breaks.
- [ ] Settings ▸ About shows version and readable 7-Zip LGPL/unRAR notice.

## Quick Look & Finder Services (M5-03, M5-06)
- [ ] Select an entry inside an archive, press ⌘Y → Quick Look preview shows the file; closing it removes the temp copy (verify no `Mac7Zip-QuickLook-*` folder remains).
- [ ] Preview an unsupported type → handled gracefully (no crash).
- [ ] In Finder, right-click an archive → Services shows Open Archive / Extract Here / Extract to Folder / Test Archive; each works.
- [ ] Right-click plain files → Services ▸ Add to Archive… opens the compression flow.
