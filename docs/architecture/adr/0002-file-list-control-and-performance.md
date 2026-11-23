# ADR-002 — File List Control and Performance Strategy

**Status:** Accepted · **Date:** 2026-11-23 · **Deciders:** Architecture

> **中文摘要**：继续使用 NSTableView 作为核心文件表格（复用单元格、缓存图标、快照式数据源），并设定可验证的大目录性能指标；SwiftUI `Table` 暂不采用。

## Context

The file list is the hottest UI path. Phase 0 uses `NSTableView` with on-demand cell creation (`FileListView.swift`, 250 LOC). Current gaps: `NSWorkspace.shared.icon(forFile:)` is called per visible row on every reload (expensive), full `reloadData()` on any change, and no large-directory benchmark. Phase 1 adds new folder/rename/delete and drag-and-drop; Phase 4 adds archive-internal listings.

## Decision Drivers

- Smooth scrolling and low memory with tens of thousands of entries.
- Precise multi-select and keyboard behavior (Return to open, arrows, type-select).
- Native look and adjustable columns.
- Testability of the underlying model independent of the control.

## Considered Options

1. **SwiftUI `Table`**: native, declarative, supports sorting/selection; less control over incremental updates and keyboard edge cases; backed by AppKit anyway.
2. **`NSTableView` with snapshot data source + cell reuse (chosen)**: proven in Phase 0; full control; can optimize per-row cost.
3. Third-party table frameworks: rejected (Native First; adds dependency and unverifiable surface).

## Decision

- Keep **`NSTableView`** behind `FileListView`/`Coordinator`.
- Introduce a **snapshot-based data source**: the store produces an immutable `[FileEntry]` snapshot plus a stable id list; the table reloads rows only when the snapshot identity changes, and uses `reloadData(forRowIndexes:columnIndexes:)` for delta updates where practical.
- **Cache file icons** by (type/extension, isDirectory) in a store-level `IconCache`; never call `NSWorkspace` per row per reload.
- Keep **row height compact (~24pt)**, support column resize, and persist column widths.
- **Performance targets** (verified by TKT-M1-02 benchmark): load 10,000-entry directory and render first screen < 500 ms on the CI baseline arm64 runner; steady scroll ≥ 55 fps; incremental sort of 10,000 items < 100 ms.

## Rationale

`NSTableView` already works and gives the control a professional file manager needs; the expensive parts are our missing caching and delta updates, not the control choice. Optimizing within the existing seam is lower-risk than a rewrite to SwiftUI `Table`.

## Consequences

- Store must expose stable identities and snapshot/delta semantics.
- Icon cache and snapshot tests required.
- If SwiftUI `Table` gains sufficient control later, it can replace the adapter without changing Domain (ADR-001 boundary preserves this option).

## Risks / Trade-offs

- Benchmark numbers on a shared CI runner are noisy; use generous thresholds and ratio-based checks.
- Over-engineering deltas is a risk; start with identity-based reload and add fine-grained deltas only if the benchmark demands.

## Related

- Specs: `SPEC-FM`
- Tickets: `TKT-M1-02`, `TKT-M6-01`
