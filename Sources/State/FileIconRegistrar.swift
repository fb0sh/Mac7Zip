import CoreServices
import Foundation
import UniformTypeIdentifiers

/// Registers Mac7Zip as the handler for archive types so Finder shows the bundled
/// per-extension icons, and can restore the previously-saved handlers
/// (Settings ▸ file icons).
///
/// Honest limitation: macOS only shows a document type's icon from the app that
/// **handles** that type, and modern macOS may require the user to confirm default
/// handler changes. Ad-hoc signed builds may also be ignored by LaunchServices.
@MainActor
final class FileIconRegistrar: ObservableObject {
    @Published private(set) var isRegistered: Bool = false

    private let defaults: UserDefaults
    private let savedKey = "Mac7Zip.savedHandlers.v1"
    private let flagKey = "Mac7Zip.iconsRegistered.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isRegistered = defaults.bool(forKey: flagKey)
    }

    /// UTI for an extension, if the system can resolve one.
    static func uti(forExtension ext: String) -> String? {
        UTType(filenameExtension: ext)?.identifier
    }

    /// Makes the system aware of Mac7Zip's document-type icons **without** changing
    /// any default app, so macOS shows **no confirmation dialogs**. Finder uses these
    /// icons for a type only when Mac7Zip is that type's default handler.
    func register() {
        refreshRegistration()
        isRegistered = true
        defaults.set(true, forKey: flagKey)
    }

    /// Sets Mac7Zip as the default handler for the chosen extensions. macOS shows
    /// **one confirmation dialog per type**, which is why this is explicit/opt-in.
    /// Returns how many were applied.
    @discardableResult
    func setDefault(
        forExtensions extensions: [String],
        bundleID: String = Bundle.main.bundleIdentifier ?? "com.mac7zip.Mac7Zip"
    ) -> Int {
        var saved: [String: String] = (defaults.dictionary(forKey: savedKey) as? [String: String]) ?? [:]
        var changed = 0
        for ext in extensions {
            guard let uti = Self.uti(forExtension: ext) else { continue }
            if saved[uti] == nil, let previous = Self.currentHandler(for: uti) {
                saved[uti] = previous
            }
            if LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleID as CFString) == noErr {
                changed += 1
            }
        }
        defaults.set(saved, forKey: savedKey)
        refreshRegistration()
        return changed
    }

    /// Restores the handlers saved before `register()`.
    @discardableResult
    func restoreDefaults() -> Int {
        let saved = (defaults.dictionary(forKey: savedKey) as? [String: String]) ?? [:]
        var restored = 0
        for (uti, handler) in saved {
            if LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, handler as CFString) == noErr {
                restored += 1
            }
        }
        defaults.removeObject(forKey: savedKey)
        isRegistered = false
        defaults.set(false, forKey: flagKey)
        refreshRegistration()
        return restored
    }

    /// Asks LaunchServices to re-scan the app bundle so icon changes take effect.
    func refreshRegistration() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.lsregisterPath)
        process.arguments = ["-f", Bundle.main.bundleURL.path]
        try? process.run()
    }

    private static var lsregisterPath: String {
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    }

    private static func currentHandler(for uti: String) -> String? {
        guard let unmanaged = LSCopyDefaultRoleHandlerForContentType(uti as CFString, .all) else { return nil }
        return unmanaged.takeRetainedValue() as String
    }
}
