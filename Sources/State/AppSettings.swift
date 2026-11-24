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

/// How to decode legacy (non-UTF-8) ZIP file names.
enum ZipFileNameEncoding: String, Codable, CaseIterable, Sendable {
    case auto
    case gbk
    case big5
    case utf8

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .gbk: return "GBK / GB2312 (936)"
        case .big5: return "Big5 (950)"
        case .utf8: return "UTF-8 (65001)"
        }
    }

    /// 7-Zip `-mcp` code page; `nil` for auto-detect.
    var codePage: Int? {
        switch self {
        case .auto: return nil
        case .gbk: return 936
        case .big5: return 950
        case .utf8: return 65001
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
    var zipEncoding: ZipFileNameEncoding = .auto
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
        didSet { persist(); applyGlobals() }
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
        applyGlobals()
    }

    func reset() {
        settings = AppSettings()
    }

    /// Propagates settings that engine code reads statically.
    private func applyGlobals() {
        SevenZipEngine.zipCodePage = settings.zipEncoding.codePage
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
