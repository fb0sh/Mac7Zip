# 7-Zip UI Reference Notes

**Status:** Internal design reference · **Last updated:** 2026-11-23

> **中文摘要**：本文件归档用户提供的 7-Zip File Manager 截图，提炼其**交互模型**（工具栏、列集、右键菜单、压缩对话框、进度对话框），并标注 Mac7Zip 的"采纳 / 适配 / 延后"决策。仅作内部设计参考，不复制其视觉风格，不随发行版分发。

## Provenance & use

- 截图由项目所有者在本地采集，仅用于 Mac7Zip 内部设计参考，存放于 `docs/reference/7zip/`，**不打包进 App、不随发行版分发**。
- 7-Zip © Igor Pavlov；许可为 GNU LGPL + unRAR 限制（见 ADR-009）。本目录图片不改变该许可，也不表示任何品牌关联。
- **不采纳**其 Windows 视觉外观；Mac7Zip 一律以 macOS 26 / Liquid Glass / Finder 原生体验为准（ADR-001、ADR-002）。

## Image index

| File | Shows |
|---|---|
| `01-main-window-single-pane.webp` | File list of a `.7z` opened in 7-Zip; toolbar + column headers + status bar. |
| `02-archive-browsing.webp` | Inside an archive: breadcrumb path, rich columns (packed size/CRC/encryption/method/counts). |
| `03-finder-context-menu-1.webp` | Explorer right-click → 7-Zip submenu (open/extract/test/add/CRC). |
| `04-finder-context-menu-2.webp` | Second Explorer context-menu variant. |
| `05-add-to-archive-dialog.webp` | "Add to Archive" dialog with format/level/method/advanced/encryption. |
| `06-progress-dialog.jpg` | Compression progress dialog with metrics. |

## Observed interaction model

### A. Toolbar operations
`添加 (Add) · 解压 (Extract) · 测试 (Test) · 复制 (Copy) · 移动 (Move) · 删除 (Delete) · 信息 (Info)`, plus an **Up / 上级** action when inside an archive.

### B. Archive-browser column set
Name · Size · **Packed Size (压缩后大小)** · Modified · Attributes (属性, e.g. RA) · **CRC** · **Encrypted (加密)** · **Method (算法, e.g. LZMA2)** · Block (字块) · **Folder count (文件夹)** · **File count (文件)**.

### C. Finder/Explorer context menu (7-Zip submenu)
Open archive (×2) · Extract files… · Extract here · Extract to "<name>\" · Test archive · Add to archive… · Compress and send by email… · Add to "<name>.7z" · Add to "<name>.zip" · CRC SHA ▸.

### D. "Add to Archive" dialog fields
Archive name/path (with Browse) · Format (7z/…) · Update mode · Compression level · Path mode · Method (LZMA2) · Dictionary size · Word size · Solid block size · CPU threads · Memory required for compress/decompress · Split volume size · Parameters · Options (self-extracting, compress shared files, delete source after) · Encryption (password, confirm, show, **AES-256**, **encrypt file names**).

### E. Progress dialog metrics
Elapsed · Remaining · Files (done/total) · Compression ratio · Total size · Speed · Processed · Packed size · Current item · progress bar.

## Adopt / Adapt / Defer for Mac7Zip

| 7-Zip element | Decision | Where |
|---|---|---|
| Seven core toolbar ops + Up | **Adopt** the operation set/order; adapt to native macOS toolbar with Back/Forward + Up and SF Symbols | SPEC-FM, SPEC-AE, MainToolbar (Phase 0) |
| Rich archive columns (packed size, CRC, encrypted, method, folder/file counts) | **Adopt** as archive-specific columns (hidden for real dirs) | SPEC-AB (FR-AB-10) |
| Extract here / Extract to "<name>/" | **Adopt** convenience extraction targets | SPEC-AE, SPEC-CW |
| Finder context-menu actions (open/extract/test/add/CRC) | **Adopt** via Finder Services/associations; **defer** email-sending | EPIC-M5 |
| Advanced Add-to-Archive fields (dictionary/word/solid/threads/split/memory estimate/delete-source/encrypt-names) | **Adapt**: collapsed "Advanced" section; **defer** full set to P2 | SPEC-CW (FR-CW-10), TKT-M3-06 |
| Modal progress window | **Adapt**: native Tasks popover + status-bar progress (non-modal) | SPEC-TM (FR-TM-10), TKT-M2-08 |
| Progress metrics (elapsed/remaining/speed/processed/ratio/current item) | **Adopt** as optional task metrics | SPEC-TM |
| Windows chrome / skin / fonts | **Reject**: use macOS 26 native look | ADR-001, ADR-002 |
| Attributes (RA) column, CRC SHA submenu, self-extracting (SFX) | **Defer** to later milestones | EPIC-M4 / EPIC-M5 |

## Mapping to tickets

- Archive columns → `TKT-M2-04` (provider fields), `TKT-M2-05` (browser columns).
- Progress metrics → `TKT-M2-08` (TaskCenter), `TKT-M2-09` (cancel).
- Advanced compression fields → `TKT-M3-06`.
- Finder context-menu actions → `EPIC-M5` (`TKT-M5-01`, `TKT-M5-06`).

## Notes / caveats

- Screenshots show a Windows host; macOS equivalents (Finder) differ — treat these as *operation-model* references only.
- Column semantics like "Folders/Files count" are aggregates 7-Zip computes for directories; we surface them only when the engine provides them (SPEC-AB).
- Do not copy icons/layout pixel-for-pixel; map intent to SF Symbols and system controls.
