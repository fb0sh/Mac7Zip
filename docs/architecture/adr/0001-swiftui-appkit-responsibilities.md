# ADR-001 — SwiftUI / AppKit Responsibility Split

**Status:** Accepted · **Date:** 2026-11-23 · **Deciders:** Architecture

> **中文摘要**：采用 SwiftUI 构建应用整体结构与表单，采用 AppKit（经 NSViewRepresentable 桥接）实现高密度文件表格和需要精细控制的键盘/选择交互。依赖单向：UI 层可依赖 AppKit，领域层不得依赖任何 UI 框架。

## Context

Phase 0 already ships a working hybrid: SwiftUI owns the `Window` scene, `NavigationSplitView`, `.toolbar`, `.commands`, sidebar, path bar, and status bar; an `NSViewRepresentable` wraps an `NSTableView` for the file list (`Sources/UI/FileList/FileListView.swift`). Phases 1–5 add a compression dialog, tasks popover, context menus, drag-and-drop, archive browsing, and Finder integration. We need an explicit, durable boundary so new features don't drift into ad-hoc hybrids.

## Decision Drivers

- macOS 26 native look (Liquid Glass) obtained automatically from system SwiftUI/AppKit controls.
- Dense tables need precise keyboard handling, selection, and row-reuse performance.
- Domain logic must be testable without launching a GUI.
- Team develops on Windows/Linux; less custom AppKit means less untestable surface.

## Considered Options

1. **Pure SwiftUI** (incl. `Table`): simplest, but keyboard/selection control and very large listings are less precise.
2. **Pure AppKit**: maximum control, much slower UI iteration, loses SwiftUI's native macOS 26 conveniences and declarative menus.
3. **Hybrid, one-directional (chosen)**: SwiftUI for structure/forms; AppKit only where precision/performance demands.

## Decision

- **SwiftUI** owns: app/scene lifecycle, `NavigationSplitView`, toolbars, menu `Commands`, sidebar, path bar, status bar, settings, sheets/forms (compression dialog), tasks popover.
- **AppKit** is used only behind `NSViewRepresentable`/`NSViewControllerRepresentable` adapters: the file list (`NSTableView`), and later `NSOpenPanel`/`NSSavePanel`/`NSWorkspace` integration.
- **AppKit/UI types never cross into Domain/Services.** Adapters translate AppKit callbacks into `BrowserStore`/`TaskCenter` commands.
- Dialogs use system panels or SwiftUI forms; we do not hand-roll window chrome.

## Rationale

Maximizes native appearance and iteration speed while retaining the performance and keyboard fidelity that a professional file manager needs. Keeps the untestable AppKit surface small and concentrated in adapters.

## Consequences

- Every AppKit integration must supply a Coordinator bridging to observable state (pattern proven in Phase 0).
- Domain layer stays UI-framework-free → host-free unit tests become possible (see ADR-010).
- Must manage actor isolation carefully at representable boundaries (Phase 0 bug: Coordinator needed `@MainActor`).

## Risks / Trade-offs

- Two UI paradigms increase cognitive load; mitigated by keeping AppKit strictly in `UI/` adapters.
- Some SwiftUI limitations (e.g., advanced selection) may force extra AppKit later; acceptable and bounded.

## Related

- Specs: `SPEC-FM`, `SPEC-AB`
- Tickets: `TKT-M1-01`, `TKT-M1-02`, `TKT-M2-05`
