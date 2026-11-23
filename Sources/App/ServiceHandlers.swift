import AppKit
import Foundation

extension Notification.Name {
    static let mac7zipQuickLook = Notification.Name("Mac7ZipQuickLook")
}

/// Finder Service entry points (TKT-M5-06). Registered via Info.plist `NSServices`
/// and routed through `ServiceActionPlanner`.
@MainActor
enum ServiceHandlers {
    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    static func handle(_ action: ServiceAction, pasteboard: NSPasteboard) -> Bool {
        let plan = ServiceActionPlanner.plan(for: action, urls: urls(from: pasteboard))
        switch plan {
        case .browse(let archive):
            FileOpenInbox.shared.enqueue(archive)
            return true
        case .extract(let archive, let subfolder):
            extract(archive: archive, subfolder: subfolder)
            return true
        case .test(let archive):
            runTest(archive: archive)
            return true
        case .create(let sources, let suggestedName):
            NotificationCenter.default.post(
                name: .mac7zipServiceCreate,
                object: nil,
                userInfo: ["sources": sources, "name": suggestedName]
            )
            return true
        case .none:
            return false
        }
    }

    private static func extract(archive: URL, subfolder: Bool) {
        guard let helper = SevenZipLocator.helperURL() else { return }
        let parent = archive.deletingLastPathComponent()
        var options = ExtractOptions(destination: parent)
        if subfolder { options.createSubfolder = archive.deletingPathExtension().lastPathComponent }
        let engine = SevenZipEngine(executableURL: helper)
        Task {
            _ = try? await engine.extract(archive: archive, to: parent, options: options)
        }
    }

    private static func runTest(archive: URL) {
        guard let helper = SevenZipLocator.helperURL() else { return }
        let engine = SevenZipEngine(executableURL: helper)
        Task { _ = try? await engine.test(archive: archive) }
    }
}

extension Notification.Name {
    static let mac7zipServiceCreate = Notification.Name("Mac7ZipServiceCreate")
}
