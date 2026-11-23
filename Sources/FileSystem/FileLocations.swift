import Foundation

/// Standard user locations. Kept in the filesystem layer so UI/State code does not
/// touch `FileManager` directly.
enum FileLocations {
    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var desktop: URL {
        first(.desktopDirectory) ?? home.appendingPathComponent("Desktop")
    }

    static var documents: URL {
        first(.documentDirectory) ?? home.appendingPathComponent("Documents")
    }

    static var downloads: URL {
        first(.downloadsDirectory) ?? home.appendingPathComponent("Downloads")
    }

    static var applications: URL {
        URL(fileURLWithPath: "/Applications", isDirectory: true)
    }

    private static func first(_ directory: FileManager.SearchPathDirectory) -> URL? {
        FileManager.default.urls(for: directory, in: .userDomainMask).first
    }
}
