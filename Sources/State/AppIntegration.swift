import Foundation

/// Notification authorization states we care about (TKT-M5-04).
enum NotificationPermission: String, Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

/// Pure decision logic for whether a completion notification should be shown,
/// kept independent of `UserNotifications` so it is unit-testable.
enum NotificationPolicy {
    static func shouldDeliver(
        permission: NotificationPermission,
        userEnabled: Bool
    ) -> Bool {
        guard userEnabled else { return false }
        switch permission {
        case .authorized, .provisional: return true
        case .denied, .notDetermined: return false
        }
    }
}

/// Remembers the last real browsing location for window restoration (TKT-M5-07).
@MainActor
final class RestorationStore: ObservableObject {
    @Published private(set) var lastPath: String?

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "Mac7Zip.lastLocation.v1") {
        self.defaults = defaults
        self.key = key
        self.lastPath = defaults.string(forKey: key)
    }

    /// Saves the last location; archive-internal paths are never stored.
    func record(_ url: URL) {
        lastPath = url.standardizedFileURL.path
        defaults.set(lastPath, forKey: key)
    }

    /// Returns the saved location if it still exists, else nil.
    func restorableURL() -> URL? {
        guard let lastPath else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: lastPath, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return URL(fileURLWithPath: lastPath)
    }

    func clear() {
        lastPath = nil
        defaults.removeObject(forKey: key)
    }
}

/// Document types declared in Info.plist (TKT-M5-01). Mirrors the CFBundleDocumentTypes
/// entries so a test can assert they stay in sync with what the app opens.
enum ArchiveDocumentTypes {
    static let extensions: [String] = ["7z", "zip", "tar", "gz", "tgz", "bz2", "xz", "rar", "cbz"]

    static let utis: [String] = [
        "org.7-zip.7-zip-archive",
        "public.zip-archive",
        "public.tar-archive",
        "org.gnu.gnu-zip-archive",
        "org.gnu.gnu-zip-tar-archive",
    ]

    static func handles(pathExtension: String) -> Bool {
        extensions.contains(pathExtension.lowercased())
    }
}
