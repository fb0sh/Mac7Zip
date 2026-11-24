import Cocoa
import FinderSync

/// Finder Sync extension (TKT-M5-06 extension point) — adds Mac7Zip actions to the
/// **first level** of Finder's context menu for monitored folders.
///
/// NOTE: a Finder Sync extension must be code-signed and notarized and run inside a
/// sandboxed App Group to be distributed (see M6-04/M6-05). This target is the
/// structural skeleton; it compiles and embeds, and works locally with ad-hoc
/// signing for testing.
class FinderSync: FIFinderSync {
    override init() {
        super.init()
        // Monitor common user folders. (A future enhancement: make this configurable.)
        let home = FileManager.default.homeDirectoryForCurrentUser
        FIFinderSyncController.default().directoryURLs = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
        ]
    }

    override var toolbarItemName: String { "Mac7Zip" }
    override var toolbarItemToolTip: String { "Mac7Zip archive actions" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "archivebox", accessibilityDescription: "Mac7Zip") ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        switch menuKind {
        case .contextualMenuForItems, .contextualMenuForContainer, .toolbarItemMenu:
            menu.addItem(withTitle: "Open Archive", action: #selector(openArchive(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Extract Here", action: #selector(extractHere(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Extract to Folder", action: #selector(extractToFolder(_:)), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Add to Archive…", action: #selector(addToArchive(_:)), keyEquivalent: "")
        default:
            break
        }
        return menu
    }

    @objc private func openArchive(_ sender: AnyObject?) { forward("openArchive") }
    @objc private func extractHere(_ sender: AnyObject?) { forward("extractHere") }
    @objc private func extractToFolder(_ sender: AnyObject?) { forward("extractToFolder") }
    @objc private func addToArchive(_ sender: AnyObject?) { forward("addToArchive") }

    /// Bridges the extension (which cannot call the host directly) to the app via a
    /// `mac7zip://action?...` URL.
    private func forward(_ action: String) {
        let items = FIFinderSyncController.default().selectedItemURLs() ?? []
        var components = URLComponents()
        components.scheme = "mac7zip"
        components.host = "action"
        var query = [URLQueryItem(name: "action", value: action)]
        query.append(contentsOf: items.map { URLQueryItem(name: "file", value: $0.path) })
        components.queryItems = query
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}
