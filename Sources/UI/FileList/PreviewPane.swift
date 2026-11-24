import AppKit
import Quartz
import SwiftUI

/// Persistent preview pane (right side) driven by the current selection.
/// Real files are previewed in place; archive entries are extracted to a private
/// temp file first and cleaned up when the selection changes.
struct PreviewPane: View {
    let target: PreviewTarget
    @State private var resolvedURL: URL?
    @State private var message: String?
    @State private var tempDirectory: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            Divider()
            ZStack {
                if let resolvedURL {
                    QuickLookView(url: resolvedURL)
                } else if let message {
                    ContentUnavailableView("Nothing to Preview", systemImage: "eye.slash", description: Text(message))
                } else {
                    ContentUnavailableView("No Selection", systemImage: "eye")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: targetKey) { await load() }
        .onDisappear { cleanUpTemp() }
    }

    private var targetKey: String {
        switch target {
        case .none: return "none"
        case .file(let url): return "file:" + url.path
        case .archiveEntry(let archive, let entry, _): return "entry:" + archive.path + ":" + entry
        }
    }

    private func load() async {
        cleanUpTemp()
        message = nil
        switch target {
        case .none:
            resolvedURL = nil
        case .file(let url):
            resolvedURL = FileManager.default.fileExists(atPath: url.path) ? url : nil
            if resolvedURL == nil { message = "The file no longer exists." }
        case .archiveEntry(let archive, let entryPath, let fileName):
            resolvedURL = nil
            guard let helper = SevenZipLocator.helperURL() else {
                message = "The 7-Zip engine isn’t available."
                return
            }
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("Mac7Zip-preview-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                tempDirectory = dir
                let engine = SevenZipEngine(executableURL: helper)
                var options = ExtractOptions(destination: dir)
                options.entries = [entryPath]
                options.password = nil
                try await engine.extract(archive: archive, to: dir, options: options)
                let produced = dir.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: produced.path) {
                    resolvedURL = produced
                } else {
                    message = "This entry can’t be previewed."
                }
            } catch {
                message = "This entry can’t be previewed."
            }
        }
    }

    private func cleanUpTemp() {
        if let tempDirectory { try? FileManager.default.removeItem(at: tempDirectory) }
        tempDirectory = nil
    }
}

/// Hosts a `QLPreviewView` (Quick Look rendering) inside SwiftUI.
struct QuickLookView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
        nsView.refreshPreviewItem()
    }
}
