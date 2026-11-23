import AppKit

/// Caches file icons by a cheap key (folder / extension) so the file list never
/// calls `NSWorkspace` once per row per reload.
final class IconCache {
    static let shared = IconCache()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    func icon(for item: FileItem) -> NSImage {
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
