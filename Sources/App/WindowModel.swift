import SwiftUI

/// Focused-value plumbing so menu commands act on the frontmost browser window.
struct BrowserStoreFocusKey: FocusedValueKey {
    typealias Value = BrowserStore
}

extension FocusedValues {
    var browserStore: BrowserStore? {
        get { self[BrowserStoreFocusKey.self] }
        set { self[BrowserStoreFocusKey.self] = newValue }
    }
}

/// Identifies one browser window. Each window owns its own `BrowserStore`, so
/// opening a second archive opens a second window (Finder-like behaviour).
struct BrowserWindow: Identifiable, Hashable {
    let id: UUID
    /// Archive or folder requested for this window (nil = start at home).
    var initialURL: URL?

    init(initialURL: URL? = nil) {
        self.id = UUID()
        self.initialURL = initialURL
    }
}

/// App-wide list of open browser windows.
@MainActor
final class WindowRegistry: ObservableObject {
    @Published var windows: [BrowserWindow] = [BrowserWindow()]

    /// Opens `url` in a new window (archives get browsed; folders get listed).
    @discardableResult
    func openInNewWindow(_ url: URL) -> UUID {
        let window = BrowserWindow(initialURL: url)
        windows.append(window)
        return window.id
    }

    func close(_ id: UUID) {
        windows.removeAll { $0.id == id }
        if windows.isEmpty { windows = [BrowserWindow()] }
    }
}
