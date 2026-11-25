import AppKit
import Foundation

/// Whether the Mac7Zip Finder Sync extension is installed/enabled (queried via
/// `pluginkit`). Pure parsing is separated so it is unit-testable.
enum FinderExtensionState: String, Sendable, Equatable {
    case enabled
    case disabled
    case notInstalled
    case unknown

    var needsAttention: Bool { self != .enabled }
}

enum FinderExtensionChecker {
    static let bundleID = "com.fb0sh.Mac7Zip.FinderSync"
    /// Quick Look preview extension (Space preview content).
    static let previewBundleID = "com.fb0sh.Mac7Zip.Preview"

    /// Parses `pluginkit -m -i <id>` output. Lines carry a leading flag:
    /// `+` = enabled, `-` = disabled. No line = not installed.
    static func parse(_ output: String, bundleID: String = bundleID) -> FinderExtensionState {
        let lines = output.split(separator: "\n").map { String($0) }
        guard let line = lines.first(where: { $0.contains(bundleID) }) else {
            return lines.isEmpty ? .notInstalled : .notInstalled
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("+") { return .enabled }
        if trimmed.hasPrefix("-") { return .disabled }
        return .unknown
    }

    /// Queries the current status asynchronously (never blocks the main thread).
    static func check(bundleID: String = bundleID) async -> FinderExtensionState {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
                process.arguments = ["-m", "-i", bundleID]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: parse(output, bundleID: bundleID))
                } catch {
                    continuation.resume(returning: .notInstalled)
                }
            }
        }
    }

    /// The extension bundled inside the running app, if present.
    static var bundledExtensionURL: URL? {
        Bundle.main.builtInPlugInsURL?.appendingPathComponent("Mac7ZipFinderSync.appex")
    }

    /// Registers the bundled extension with the system (best effort).
    static func registerBundledExtension() {
        guard let appex = bundledExtensionURL, FileManager.default.fileExists(atPath: appex.path) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-a", appex.path]
        try? process.run()
    }

    /// Registers + enables the Quick Look preview extension.
    static func enablePreview() {
        guard let previewAppex = Bundle.main.builtInPlugInsURL?.appendingPathComponent("Mac7ZipPreview.appex"),
              FileManager.default.fileExists(atPath: previewAppex.path) else { return }
        runPluginkit(["-a", previewAppex.path])
        runPluginkit(["-e", "use", "-i", previewBundleID])
    }

    /// Registers AND enables the bundled extension via `pluginkit` (macOS Sequoia+
    /// removed the System Settings list, so enabling programmatically is required).
    static func enable() {
        guard let appex = bundledExtensionURL else { return }
        runPluginkit(["-a", appex.path])
        runPluginkit(["-e", "use", "-i", bundleID])
        enablePreview()
        // Ask LaunchServices to re-scan the containing app.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
        process.arguments = ["-f", Bundle.main.bundleURL.path]
        try? process.run()
    }

    private static func runPluginkit(_ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }

    /// Opens the system UI where the user enables Finder extensions.
    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.FinderSync",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }
}
