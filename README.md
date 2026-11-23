# Mac7Zip

Mac7Zip is a native, lightweight archive and file-management app for **macOS 26+**, inspired by the efficiency of Windows 7-Zip File Manager while following Apple's Human Interface Guidelines and native macOS 26 design (Liquid Glass, system toolbars, sidebars, menus, and sheets).

The project is built with **Swift**, **SwiftUI**, and **AppKit**, and is developed primarily on Windows/Linux with all macOS compilation and testing performed on **GitHub Actions**.

> **Phase 0 status:** this repository implements the application shell, the native file browser, and the CI pipeline. Archive compression/extraction is **not** implemented yet — those toolbar and menu actions are intentionally disabled.

## Features (Phase 0)

- Native macOS window with system title bar, toolbar, sidebar, and standard window controls (close/minimise/zoom, resize, full screen, light/dark mode).
- Sidebar with Home, Desktop, Documents, Downloads, and Applications.
- File browser listing real directory contents with Name, Size, Kind, and Date Modified columns.
- Sort by clicking a column header (name, size, kind, date; ascending/descending).
- Single/multi-row selection; the status bar shows item count, selected count, and total selected size.
- Double-click a folder to open it; double-click a file to open it with the system default app.
- Breadcrumb path bar with a manual path-entry mode.
- Back / Forward / Enclosing-folder navigation with history.
- Native menu bar (File, Edit, View, Go, Tools, Window, Help) plus Go/Tools commands.
- Archive actions (Add / Extract / Test / Copy / Move / Delete / Info) are present but **disabled**.
- Unit tests for file sorting, path utilities, and byte-count formatting.

## Tech stack

| Area | Choice |
| --- | --- |
| Language | Swift |
| UI | SwiftUI + AppKit (`NSViewRepresentable` around `NSTableView`) |
| Minimum OS | macOS 26.0 |
| Toolchain | Xcode 26+ |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) |
| Dependencies | Swift Package Manager (as needed; none in Phase 0) |
| Build system | `xcodebuild` |
| CI | GitHub Actions (`macos-26` runner) |
| Architecture | arm64 first, designed to remain compatible with x86_64 |
| Archive engine | 7zz (integrated in a later phase) |

## Requirements

- **To build locally:** macOS 26 with Xcode 26+, plus `xcodegen` (`brew install xcodegen`).
- **To build in CI:** nothing local — GitHub Actions provides the macOS 26 runner and Xcode 26 toolchain.
- **To run the app:** macOS 26+.

## Project structure

```
Mac7Zip/
├── project.yml                     # XcodeGen project definition (app + test targets)
├── .github/workflows/build.yml     # CI: compile, test, release build, zip + artifact
├── Sources/
│   ├── App/                        # App entry point, window scene, menu commands
│   │   ├── Mac7ZipApp.swift
│   │   └── Mac7ZipCommands.swift
│   ├── UI/                         # SwiftUI views + AppKit file table
│   │   ├── ContentView.swift
│   │   ├── Sidebar/
│   │   ├── Toolbar/
│   │   ├── FileList/               # NSTableView-based listing
│   │   ├── PathNavigation/
│   │   └── StatusBar/
│   ├── FileSystem/                 # Directory reads, sorting, path helpers, size formatting
│   ├── Archive/                    # ArchiveEngine protocol + supporting types (7zz seam)
│   ├── Models/                     # FileItem, sort descriptor
│   ├── State/                      # FileBrowserModel (observable browsing state)
│   └── Resources/                  # Asset catalog
├── Tests/Mac7ZipTests/             # XCTest unit tests
└── docs/agents/                    # Agent skills configuration (issue tracker, domain docs)
```

The generated `Mac7Zip.xcodeproj` is **not** committed — it is regenerated from `project.yml` locally and in CI, so the build never depends on hand-edited Xcode state.

## Local macOS build

```bash
brew install xcodegen
xcodegen generate
open Mac7Zip.xcodeproj      # or build from the command line:
xcodebuild -project Mac7Zip.xcodeproj -scheme Mac7Zip -configuration Debug \
  -destination 'platform=macOS' build
```

Run the unit tests:

```bash
xcodebuild test -project Mac7Zip.xcodeproj -scheme Mac7Zip \
  -destination 'platform=macOS'
```

## GitHub Actions build

The workflow in `.github/workflows/build.yml` runs on:

- every push to `main`,
- every pull request,
- manual `workflow_dispatch`.

Steps:

1. Check out the repository.
2. Select and **verify** an Xcode 26.x toolchain (`xcodebuild -version`), failing if it is not 26.x.
3. Install XcodeGen.
4. Generate `Mac7Zip.xcodeproj` from `project.yml`.
5. Compile check (Debug).
6. Run unit tests.
7. Release build for arm64 with code signing disabled (no Apple Developer account required).
8. Package the real `Mac7Zip.app` into `Mac7Zip-arm64.zip` with `ditto`.
9. Upload the ZIP as the `Mac7Zip-arm64` artifact (logs are uploaded on failure).

Download the artifact from the workflow run's **Artifacts** section.

## Current limitations (Phase 0)

- No archive/compression functionality yet; archive-related commands are disabled.
- No archive internal browsing, drag-and-drop, task progress, password prompts, file associations, or Finder integration.
- Single-pane browsing only; the dual-pane layout is a future feature.
- arm64 builds only; Universal Binary, code signing, DMG packaging, and notarization are future work.
- The app is not sandboxed in Phase 0, so macOS privacy prompts (Desktop/Documents/Downloads) may appear on first access.

## Roadmap

- **Phase 1:** integrate the official `7zz` engine as a managed subprocess; implement Add/Extract/Test with task progress and cancellation.
- **Phase 2:** archive-internal browsing, password entry, drag-and-drop, and compression dialogs.
- **Phase 3:** dual-pane file management, custom favourites, search, and view options.
- **Phase 4:** file associations, Finder integration, code signing, DMG packaging, notarization, and Universal Binary.

## License

**License scheme to be confirmed — not chosen yet.** No `LICENSE` file is included deliberately. Common options for a project like this are MIT, Apache-2.0, or GPL-3.0 (which matches 7-Zip's own license spirit). A maintainer decision is required before this file is added.
