import Combine
import Foundation

/// Holds a file URL that arrived from Finder (double-click / Open With) so the
/// SwiftUI view hierarchy can react once it is ready (TKT-M5-01).
@MainActor
final class FileOpenInbox: ObservableObject {
    static let shared = FileOpenInbox()
    @Published var pendingURL: URL?

    private init() {}

    func enqueue(_ url: URL) {
        guard url.isFileURL else { return }
        pendingURL = url
    }

    func take() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }
}
