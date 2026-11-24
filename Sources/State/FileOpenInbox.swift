import Combine
import Foundation

/// A file URL that arrived from Finder (double-click / Open With / service).
/// Carries a unique id so exactly **one** window/observer can claim it.
struct PendingOpen: Equatable, Sendable {
    let id: UUID
    let url: URL
}

/// Holds at most one pending open request. Every window observes it, but only the
/// first `claim(_:)` wins; the rest get `nil`. This prevents the same archive from
/// being opened twice (the "two copies" bug).
@MainActor
final class FileOpenInbox: ObservableObject {
    static let shared = FileOpenInbox()
    @Published var pendingOpen: PendingOpen?

    private init() {}

    func enqueue(_ url: URL) {
        guard url.isFileURL else { return }
        pendingOpen = PendingOpen(id: UUID(), url: url)
    }

    /// Returns the URL only if `id` is still the current request; clears it so no
    /// other observer can consume the same request.
    func claim(_ id: UUID) -> URL? {
        guard let pending = pendingOpen, pending.id == id else { return nil }
        pendingOpen = nil
        return pending.url
    }
}
