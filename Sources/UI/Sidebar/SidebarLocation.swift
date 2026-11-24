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
        switch self {
        case .home: return FileLocations.home
        case .desktop: return FileLocations.desktop
        case .documents: return FileLocations.documents
        case .downloads: return FileLocations.downloads
        case .applications: return FileLocations.applications
        }
    }
}
