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
        case promise(entryPath: String, fileName: String)
        case none
    }

    static func payload(for item: FileItem, isInsideArchive: Bool) -> Payload {
        if isInsideArchive {
            guard !item.isDirectory else { return .none }
            let name = (item.name as NSString).lastPathComponent
            return .promise(entryPath: item.name, fileName: name)
        }
        return .fileURL(item.url)
    }

    /// The file name 7-Zip produces for an entry (last path component), which is
    /// what the promise must copy to the drop location.
    static func producedFileName(entryPath: String) -> String {
        (entryPath as NSString).lastPathComponent
    }

    /// File type identifier for a promised name; falls back to a generic type.
    static func fileType(for name: String) -> String {
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty,
              let type = UTType(filenameExtension: ext)?.identifier else {
            return UTType.data.identifier
        }
        return type
    }
}
