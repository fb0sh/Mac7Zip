import Foundation

/// Advanced 7z creation parameters (SPEC-CW FR-CW-10).
///
/// Everything here is optional: `nil` means "leave 7zz's default alone" so the
/// simple path stays simple. Values are validated before mapping to argv.
struct AdvancedCompressionOptions: Sendable, Equatable {
    /// 7z dictionary size, e.g. "32m", "64m".
    var dictionarySize: String?
    /// 7z word size (fast bytes), e.g. "32", "64".
    var wordSize: String?
    /// 7z solid block size, e.g. "8g", "off".
    var solidBlockSize: String?
    /// Worker thread count; `nil` = automatic.
    var threadCount: Int?
    /// Multi-volume size, e.g. "100m"; `nil` = single file.
    var volumeSize: String?
    /// Update mode: add+replace (default), add only, or fresh archive.
    var updateMode: UpdateMode = .addAndReplace
    /// Relative or full paths inside the archive.
    var pathMode: PathMode = .relative
    /// Delete source files after a successful create.
    var deleteSourceAfter = false

    enum UpdateMode: String, Sendable, CaseIterable {
        case addAndReplace
        case addOnly
        case fresh

        var displayName: String {
            switch self {
            case .addAndReplace: return "Add and replace files"
            case .addOnly: return "Add and update"
            case .fresh: return "Create a new archive"
            }
        }

        /// 7zz `-up` value; `nil` means use the default.
        var switchValue: String? {
            switch self {
            case .addAndReplace: return nil
            case .addOnly: return "1"
            case .fresh: return "0"
            }
        }
    }

    enum PathMode: String, Sendable, CaseIterable {
        case relative
        case full

        var displayName: String {
            switch self {
            case .relative: return "Relative paths"
            case .full: return "Full paths"
            }
        }

        var switchValue: String { self == .relative ? "r0" : "r1" }
    }
}

enum AdvancedCompressionValidator {
    enum Problem: Equatable {
        case invalidSize(field: String, value: String)
        case invalidWordSize(String)
        case invalidThreadCount(Int)
        case unsupportedForZip(field: String)
    }

    /// Accepts values like "32m", "1g", "512k", or plain bytes.
    static func isValidSize(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !value.isEmpty else { return false }
        let digits = value.dropLast(value.last?.isLetter == true ? 1 : 0)
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber), Int(digits) != nil else { return false }
        if let last = value.last, last.isLetter {
            return ["k", "m", "g", "b"].contains(String(last))
        }
        return true
    }

    static func validate(_ options: AdvancedCompressionOptions, format: ArchiveFormat) -> [Problem] {
        var problems: [Problem] = []

        if let dictionary = options.dictionarySize, !dictionary.isEmpty, !isValidSize(dictionary) {
            problems.append(.invalidSize(field: "Dictionary size", value: dictionary))
        }
        if let solid = options.solidBlockSize, !solid.isEmpty,
           solid.lowercased() != "off", !isValidSize(solid) {
            problems.append(.invalidSize(field: "Solid block size", value: solid))
        }
        if let volume = options.volumeSize, !volume.isEmpty, !isValidSize(volume) {
            problems.append(.invalidSize(field: "Volume size", value: volume))
        }
        if let word = options.wordSize, !word.isEmpty {
            if let number = Int(word), (1...273).contains(number) {
                // valid
            } else {
                problems.append(.invalidWordSize(word))
            }
        }
        if let threads = options.threadCount, threads < 1 || threads > 256 {
            problems.append(.invalidThreadCount(threads))
        }
        // These are 7z-only concepts.
        if format != .sevenZip {
            if options.dictionarySize?.isEmpty == false { problems.append(.unsupportedForZip(field: "Dictionary size")) }
            if options.wordSize?.isEmpty == false { problems.append(.unsupportedForZip(field: "Word size")) }
            if options.solidBlockSize?.isEmpty == false { problems.append(.unsupportedForZip(field: "Solid block size")) }
        }
        return problems
    }

    static func describe(_ problem: Problem) -> String {
        switch problem {
        case .invalidSize(let field, let value): return "\(field) “\(value)” isn’t a valid size (use e.g. 32m, 1g)."
        case .invalidWordSize(let value): return "Word size “\(value)” must be 1–273."
        case .invalidThreadCount(let count): return "Thread count \(count) must be 1–256."
        case .unsupportedForZip(let field): return "\(field) only applies to 7z archives."
        }
    }

    /// Maps advanced options to 7zz switches (empty when nothing is set).
    static func arguments(for options: AdvancedCompressionOptions, format: ArchiveFormat) -> [String] {
        var args: [String] = []

        if let update = options.updateMode.switchValue {
            args.append("-up\(update)")
        }
        args.append("-sp\(options.pathMode.switchValue)")

        if format == .sevenZip {
            if let dictionary = options.dictionarySize, !dictionary.isEmpty {
                args.append("-md=\(dictionary)")
            }
            if let word = options.wordSize, !word.isEmpty {
                args.append("-mfb=\(word)")
            }
            if let solid = options.solidBlockSize, !solid.isEmpty {
                args.append("-ms=\(solid)")
            }
        }
        if let threads = options.threadCount {
            args.append("-mmt=\(threads)")
        }
        if let volume = options.volumeSize, !volume.isEmpty {
            args.append("-v\(volume)")
        }
        return args
    }
}
