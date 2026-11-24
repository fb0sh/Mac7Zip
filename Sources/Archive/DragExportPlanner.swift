import Foundation
import UniformTypeIdentifiers

/// Builds drag payloads for the file list (TKT-M4-09).
///
/// - Real files: a plain file URL, so Finder moves/copies natively.
/// - Archive entries: a **file promise**, materialised on drop by extracting just
///   that entry into a private staging directory. Nothing is written until the
///   drop is accepted.
enum DragExportPlanner {
    /// What a row should advertise to the pasteboard.
    enum Payload: Equatable {
        case fileURL(URL)
        case promise(entryPath: String, fileName: String, isDirectory: Bool)
        case none
    }

    /// `internalPath` is the current archive subfolder ("" at archive root).
    static func payload(for item: FileItem, isInsideArchive: Bool, internalPath: String = "") -> Payload {
        if isInsideArchive {
            let normalizedInternal = normalize(internalPath)
            let entryPath = normalizedInternal.isEmpty ? item.name : normalizedInternal + "/" + item.name
            let name = (item.name as NSString).lastPathComponent
            return .promise(entryPath: entryPath, fileName: name, isDirectory: item.isDirectory)
        }
        return .fileURL(item.url)
    }

    static func normalize(_ path: String) -> String {
        var value = path.replacingOccurrences(of: "\\", with: "/")
        while value.hasPrefix("/") { value.removeFirst() }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// The file name 7-Zip produces for an entry (last path component), which is
    /// what the promise must copy to the drop location.
    static func producedFileName(entryPath: String) -> String {
        (entryPath as NSString).lastPathComponent
    }

    /// File type identifier for a promised item; folders use `public.folder`.
    static func fileType(for name: String, isDirectory: Bool = false) -> String {
        if isDirectory { return UTType.folder.identifier }
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty,
              let type = UTType(filenameExtension: ext)?.identifier else {
            return UTType.data.identifier
        }
        return type
    }
}
