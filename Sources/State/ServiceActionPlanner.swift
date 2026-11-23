import Foundation

/// Maps a Finder Service action to an engine operation (TKT-M5-06).
///
/// Kept pure so the routing is unit-testable without NSServices. Actual service
/// invocation is registered in Info.plist (`NSServices`) and handled by the
/// app delegate.
enum ServiceAction: String, CaseIterable, Sendable {
    case openArchive = "openArchive"
    case extractHere = "extractHere"
    case extractToFolder = "extractToFolder"
    case extractFiles = "extractFiles"
    case testArchive = "testArchive"
    case addToArchive = "addToArchive"

    var menuTitle: String {
        switch self {
        case .openArchive: return "Open Archive"
        case .extractHere: return "Extract Here"
        case .extractToFolder: return "Extract to <name>/"
        case .extractFiles: return "Extract Files…"
        case .testArchive: return "Test Archive"
        case .addToArchive: return "Add to Archive…"
        }
    }
}

/// What a service action should do with a set of selected URLs.
enum ServicePlan: Equatable {
    /// Browse the given archive.
    case browse(URL)
    /// Extract an archive next to itself (optionally into a subfolder).
    case extract(archive: URL, subfolder: Bool)
    /// Create an archive from these items (destination chosen by UI).
    case create(sources: [URL], suggestedName: String)
    /// Run an integrity test.
    case test(archive: URL)
    /// Not enough/appropriate input.
    case none
}

enum ServiceActionPlanner {
    static func plan(for action: ServiceAction, urls: [URL]) -> ServicePlan {
        guard let first = urls.first else { return .none }
        switch action {
        case .openArchive:
            guard isArchive(first) else { return .none }
            return .browse(first)
        case .extractHere:
            guard isArchive(first) else { return .none }
            return .extract(archive: first, subfolder: false)
        case .extractToFolder:
            guard isArchive(first) else { return .none }
            return .extract(archive: first, subfolder: true)
        case .extractFiles:
            guard isArchive(first) else { return .none }
            return .extract(archive: first, subfolder: false)
        case .testArchive:
            guard isArchive(first) else { return .none }
            return .test(archive: first)
        case .addToArchive:
            guard !urls.isEmpty else { return .none }
            let suggested = urls.count == 1
                ? first.deletingPathExtension().lastPathComponent + ".7z"
                : "Archive.7z"
            return .create(sources: urls, suggestedName: suggested)
        }
    }

    private static func isArchive(_ url: URL) -> Bool {
        ArchiveFormat.detect(from: url) != nil
    }
}
