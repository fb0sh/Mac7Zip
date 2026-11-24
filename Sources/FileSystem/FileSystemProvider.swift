import Foundation

/// Capabilities a provider supports. The UI enables/disables actions from these
/// flags rather than ad-hoc checks, so archive (read-only) listings automatically
/// disable mutating actions.
struct FileSystemCapabilities: OptionSet, Sendable {
    let rawValue: Int

    static let list = FileSystemCapabilities(rawValue: 1 << 0)
    static let readFile = FileSystemCapabilities(rawValue: 1 << 1)
    static let writeFile = FileSystemCapabilities(rawValue: 1 << 2)
    static let rename = FileSystemCapabilities(rawValue: 1 << 3)
    static let delete = FileSystemCapabilities(rawValue: 1 << 4)
    static let createDirectory = FileSystemCapabilities(rawValue: 1 << 5)
}

enum FileSystemProviderKind: Sendable, Equatable {
    case real
    case archive
}

enum FileSystemProviderError: Error, Equatable {
    case unsupportedLocation
}

/// Lists entries for a `BrowserLocation`. Real and archive implementations share
/// this seam so the same browser UI can render both.
protocol FileSystemProvider: Sendable {
    var kind: FileSystemProviderKind { get }
    var capabilities: FileSystemCapabilities { get }
    func list(_ location: BrowserLocation) async throws -> [FileItem]
}

/// Real filesystem provider: read/write capable, backed by `FileAccess`.
struct RealFileSystemProvider: FileSystemProvider {
    let access: FileAccess

    init(access: FileAccess = RealFileAccess()) {
        self.access = access
    }

    var kind: FileSystemProviderKind { .real }

    var capabilities: FileSystemCapabilities {
        [.list, .readFile, .writeFile, .rename, .delete, .createDirectory]
    }

    func list(_ location: BrowserLocation) async throws -> [FileItem] {
        guard let url = location.realURL else {
            throw FileSystemProviderError.unsupportedLocation
        }
        return try await access.contents(of: url)
    }
}
