#if canImport(Darwin)
import Darwin
#endif
import Foundation

/// Read-only snapshot of file metadata plus permission editing (TKT-M4-06).
struct FileMetadata: Sendable, Equatable {
    var url: URL
    var name: String
    var kind: String
    var size: Int64
    var isDirectory: Bool
    var isSymlink: Bool
    var linkTarget: String?
    var creationDate: Date?
    var modificationDate: Date?
    var ownerName: String?
    var groupName: String?
    var posixPermissions: UInt16?
    var isReadable: Bool
    var isWritable: Bool
    var isExecutable: Bool
    var itemCount: Int?
    var finderTags: [String]

    /// `rwxr-xr-x` style description; `nil` when permissions are unavailable.
    var permissionString: String? {
        guard let mode = posixPermissions else { return nil }
        return Self.describe(mode)
    }

    /// Formats POSIX mode bits as `rwxr-xr-x`.
    static func describe(_ mode: UInt16) -> String {
        func bits(_ shift: UInt16) -> String {
            let value = (mode >> shift) & 0o7
            var result = ""
            result += (value & 0o4) != 0 ? "r" : "-"
            result += (value & 0o2) != 0 ? "w" : "-"
            result += (value & 0o1) != 0 ? "x" : "-"
            return result
        }
        return bits(6) + bits(3) + bits(0)
    }
}

enum FileMetadataError: Error, Equatable {
    case notFound(String)
    case permissionDenied(String)
    case failed(String)
}

struct FileMetadataService: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func metadata(for url: URL) throws -> FileMetadata {
        let keys: Set<URLResourceKey> = [
            .nameKey, .fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey,
            .creationDateKey, .contentModificationDateKey,
            .isReadableKey, .isWritableKey, .isExecutableKey,
            .localizedTypeDescriptionKey,
        ]
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: keys)
        } catch {
            let nsError = error as NSError
            if nsError.code == NSFileReadNoSuchFileError {
                throw FileMetadataError.notFound(url.lastPathComponent)
            }
            if nsError.code == NSFileReadNoPermissionError {
                throw FileMetadataError.permissionDenied(url.lastPathComponent)
            }
            throw FileMetadataError.failed(error.localizedDescription)
        }

        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let posix = (attributes?[.posixPermissions] as? NSNumber)?.uint16Value

        var itemCount: Int?
        if values.isDirectory == true {
            itemCount = (try? fileManager.contentsOfDirectory(atPath: url.path).count)
        }

        return FileMetadata(
            url: url,
            name: values.name ?? url.lastPathComponent,
            kind: values.localizedTypeDescription ?? (values.isDirectory == true ? "Folder" : "Document"),
            size: Int64(values.fileSize ?? 0),
            isDirectory: values.isDirectory ?? false,
            isSymlink: values.isSymbolicLink ?? false,
            linkTarget: (try? fileManager.destinationOfSymbolicLink(atPath: url.path)),
            creationDate: values.creationDate,
            modificationDate: values.contentModificationDate,
            ownerName: attributes?[.ownerAccountName] as? String,
            groupName: attributes?[.groupOwnerAccountName] as? String,
            posixPermissions: posix,
            isReadable: values.isReadable ?? false,
            isWritable: values.isWritable ?? false,
            isExecutable: values.isExecutable ?? false,
            itemCount: itemCount,
            finderTags: FinderTagService.tags(for: url)
        )
    }

    /// Applies new POSIX permissions, preserving the file type bits.
    func setPermissions(_ mode: UInt16, for url: URL) throws {
        do {
            try fileManager.setAttributes([.posixPermissions: NSNumber(value: mode)], ofItemAtPath: url.path)
        } catch {
            let nsError = error as NSError
            if nsError.code == NSFileWriteNoPermissionError {
                throw FileMetadataError.permissionDenied(url.lastPathComponent)
            }
            throw FileMetadataError.failed(error.localizedDescription)
        }
    }
}

/// Reads and writes Finder tags stored in the `com.apple.metadata:_kMDItemUserTags`
/// extended attribute (TKT-M4-08).
enum FinderTagService {
    private static let attributeName = "com.apple.metadata:_kMDItemUserTags"

    static func tags(for url: URL) -> [String] {
        guard let data = try? extendedAttribute(named: attributeName, at: url) else { return [] }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
        guard let raw = plist as? [String] else { return [] }
        // Entries look like "Red\n6"; keep only the tag name.
        return raw.map { $0.components(separatedBy: "\n").first ?? $0 }
    }

    static func setTags(_ tags: [String], for url: URL) throws {
        if tags.isEmpty {
            try? removeExtendedAttribute(named: attributeName, at: url)
            return
        }
        let plist = tags.map { "\($0)\n0" }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try writeExtendedAttribute(named: attributeName, value: data, at: url)
    }

    // MARK: - POSIX xattr helpers

    static func extendedAttribute(named name: String, at url: URL) throws -> Data {
        let length = getxattr(url.path, name, nil, 0, 0, 0)
        guard length > 0 else { throw FileMetadataError.failed("No such attribute") }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            getxattr(url.path, name, buffer.baseAddress, length, 0, 0)
        }
        guard result >= 0 else { throw FileMetadataError.failed("Unable to read attribute") }
        return data
    }

    static func writeExtendedAttribute(named name: String, value: Data, at url: URL) throws {
        let result = value.withUnsafeBytes { buffer in
            setxattr(url.path, name, buffer.baseAddress, value.count, 0, 0)
        }
        guard result == 0 else { throw FileMetadataError.failed("Unable to write attribute") }
    }

    static func removeExtendedAttribute(named name: String, at url: URL) throws {
        removexattr(url.path, name, 0)
    }
}
