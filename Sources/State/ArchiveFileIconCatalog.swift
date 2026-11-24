import Foundation

/// Maps archive file extensions to the bundled per-type icons (TKT follow-up).
/// Pure data + matching logic so it is unit-testable.
enum ArchiveFileIconCatalog {
    /// Extensions that ship with a dedicated icon (longest match wins).
    static let extensions: [String] = [
        "7z", "apk", "arj", "bz2", "cab", "gz", "img", "iso", "lz4", "lzh", "lzma",
        "rar", "tar.gz", "tar", "tar.xz", "tar.zst", "tbz2", "tgz", "wim", "xar",
        "xz", "zip", "zst",
    ]

    /// Resource base name (without `.icns`) for an extension, e.g. "tar.gz" -> "tar_gz".
    static func resourceName(forExtension ext: String) -> String? {
        let lower = ext.lowercased()
        guard extensions.contains(lower) else { return nil }
        return lower.replacingOccurrences(of: ".", with: "_")
    }

    /// Best icon resource for a full file name, preferring multi-part extensions
    /// ("archive.tar.gz" → tar_gz, not gz). Returns the resource base name.
    static func resourceName(forFileName name: String) -> String? {
        let lower = name.lowercased()
        for ext in extensions.sorted(by: { $0.count > $1.count }) {
            if lower.hasSuffix("." + ext) { return ext.replacingOccurrences(of: ".", with: "_") }
        }
        return nil
    }
}
