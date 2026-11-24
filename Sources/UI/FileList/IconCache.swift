import AppKit

/// Caches file icons by a cheap key (folder / extension) so the file list never
/// calls `NSWorkspace` once per row per reload.
final class IconCache {
    static let shared = IconCache()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    func icon(for item: FileItem) -> NSImage {
        // Application bundles are directories but must show the app's own icon.
        if item.archiveMetadata == nil, item.isApplicationBundle {
            let pathKey = "app:" + item.url.path
            lock.lock()
            if let cached = cache[pathKey] { lock.unlock(); return cached }
            lock.unlock()
            let image = NSWorkspace.shared.icon(forFile: item.url.path)
            lock.lock(); cache[pathKey] = image; lock.unlock()
            return image
        }

        // Archive files get their dedicated bundled icon (by extension).
        if item.archiveMetadata == nil, let resource = ArchiveFileIconCatalog.resourceName(forFileName: item.name),
           let url = Bundle.main.url(forResource: resource, withExtension: "icns") {
            let pathKey = "arc:" + resource
            lock.lock()
            if let cached = cache[pathKey] { lock.unlock(); return cached }
            lock.unlock()
            let image = NSImage(contentsOf: url) ?? NSWorkspace.shared.icon(forFileType: url.pathExtension)
            lock.lock(); cache[pathKey] = image; lock.unlock()
            return image
        }

        let key: String
        if item.isDirectory {
            key = "public.folder"
        } else {
            let ext = item.url.pathExtension.lowercased()
            key = ext.isEmpty ? "public.data" : ext
        }

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = NSWorkspace.shared.icon(forFileType: key)
        lock.lock()
        cache[key] = image
        lock.unlock()
        return image
    }
}
