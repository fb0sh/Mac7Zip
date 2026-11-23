import Foundation

/// The fixed set of favourite locations shown in the sidebar. Custom user
/// favourites are a later-phase feature; this enum is the extension point.
enum SidebarLocation: String, CaseIterable, Identifiable, Hashable {
    case home
    case desktop
    case documents
    case downloads
    case applications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .desktop: return "Desktop"
        case .documents: return "Documents"
        case .downloads: return "Downloads"
        case .applications: return "Applications"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .desktop: return "display"
        case .documents: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .applications: return "square.grid.2x2"
        }
    }

    var url: URL {
        let fileManager = FileManager.default
        switch self {
        case .home:
            return fileManager.homeDirectoryForCurrentUser
        case .desktop:
            return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        case .documents:
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        case .downloads:
            return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        case .applications:
            return URL(fileURLWithPath: "/Applications", isDirectory: true)
        }
    }
}
