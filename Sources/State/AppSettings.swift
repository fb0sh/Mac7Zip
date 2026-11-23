import Combine
import Foundation

/// What a double-click on an archive does (SPEC-MI AC-MI-3; owner's key setting).
enum ArchiveActivation: String, Codable, CaseIterable, Sendable {
    /// Open the archive and browse its contents (default).
    case open
    /// Extract the archive to a sibling `<name>/` folder.
    case extract

    var displayName: String {
        switch self {
        case .open: return "Open in Mac7Zip"
        case .extract: return "Extract to <name>/ folder"
        }
    }
}

/// Persisted application preferences with validation (TKT-M5-02).
struct AppSettings: Codable, Equatable, Sendable {
    var activation: ArchiveActivation = .open
    var extractSubfolderByDefault: Bool = true
    var defaultExtractPath: String?
    var maxTotalBytes: Int64 = 4 * 1024 * 1024 * 1024
    var maxExpansionRatio: Double = 100
    var maxEntryCount: Int = 1_000_000
    var defaultFormatRaw: String = "7z"
    var sendCompletionNotifications: Bool = false
    var restoreLastLocation: Bool = true

    /// Extraction limits derived from the settings.
    var extractionLimits: ExtractionLimits {
        ExtractionLimits(
            maxTotalBytes: maxTotalBytes,
            maxExpansionRatio: maxExpansionRatio,
            maxEntryCount: maxEntryCount
        )
    }

    /// Validation problems, empty when valid.
    var validationErrors: [String] {
        var errors: [String] = []
        if maxTotalBytes <= 0 { errors.append("Maximum total size must be greater than zero.") }
        if maxExpansionRatio < 1 { errors.append("Maximum expansion ratio must be at least 1.") }
        if maxEntryCount < 1 { errors.append("Maximum entry count must be at least 1.") }
        return errors
    }

    var isValid: Bool { validationErrors.isEmpty }
}

/// Store for `AppSettings`, persisted as JSON (TKT-M5-02).
@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "Mac7Zip.settings.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    func reset() {
        settings = AppSettings()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
