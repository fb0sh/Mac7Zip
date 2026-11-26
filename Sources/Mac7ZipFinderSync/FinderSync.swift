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
        // Monitor the home folder tree: archives are rarely confined to the three
        // standard folders, and a Finder Sync extension only shows its menu inside
        // the directories it monitors.
        let home = FileManager.default.homeDirectoryForCurrentUser
        FIFinderSyncController.default().directoryURLs = [home]
    }

    override var toolbarItemName: String { "Mac7Zip" }
    override var toolbarItemToolTip: String { "Mac7Zip archive actions" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "archivebox", accessibilityDescription: "Mac7Zip") ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        guard menuKind == .contextualMenuForItems
            || menuKind == .contextualMenuForContainer
            || menuKind == .toolbarItemMenu else {
            return menu
        }

        // Finder only renders items whose target is reachable from the extension.
        // Items without an explicit target are dropped, leaving an empty menu.
        addItem(to: menu, title: "解压到当前文件夹", action: #selector(extractHere(_:)))
        addItem(to: menu, title: "解压到「名称」文件夹", action: #selector(extractToFolder(_:)))
        addItem(to: menu, title: "用 Mac7Zip 打开", action: #selector(openArchive(_:)))
        menu.addItem(.separator())
        addItem(to: menu, title: "添加到压缩包…", action: #selector(addToArchive(_:)))
        return menu
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc func openArchive(_ sender: AnyObject?) { forward("openArchive") }
    @objc func extractHere(_ sender: AnyObject?) { forward("extractHere") }
    @objc func extractToFolder(_ sender: AnyObject?) { forward("extractToFolder") }
    @objc func addToArchive(_ sender: AnyObject?) { forward("addToArchive") }

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
