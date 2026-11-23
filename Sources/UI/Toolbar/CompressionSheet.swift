import AppKit
import SwiftUI

/// Native "Add to Archive" sheet (SPEC-CW FR-CW-02…04).
///
/// Advanced options live in a collapsed disclosure; the default path stays a
/// single name + format + level. Password controls are present but disabled with
/// an explanation because 7zz's prompt is console-bound (ADR-005).
struct CompressionSheet: View {
    let sources: [URL]
    let defaultDirectory: URL
    let onCreate: (CompressionRequest) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var directory: URL
    @State private var format: ArchiveFormat = .sevenZip
    @State private var level: Int = 5
    @State private var showAdvanced = false
    @State private var method: String = "LZMA2"
    @State private var encryptFileNames = false
    @State private var validationMessages: [String] = []

    init(
        sources: [URL],
        defaultDirectory: URL,
        onCreate: @escaping (CompressionRequest) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sources = sources
        self.defaultDirectory = defaultDirectory
        self.onCreate = onCreate
        self.onCancel = onCancel
        _directory = State(initialValue: defaultDirectory)
        _name = State(initialValue: CompressionPlanner.suggestedArchiveName(for: sources, format: .sevenZip))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    LabeledContent("Save To") {
                        HStack {
                            Text(directory.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Button("Choose…") { chooseDirectory() }
                        }
                    }
                    TextField("Archive name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Picker("Format", selection: $format) {
                        Text("7z").tag(ArchiveFormat.sevenZip)
                        Text("ZIP").tag(ArchiveFormat.zip)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: format) { _, newValue in
                        name = renameForFormat(name, to: newValue)
                    }
                    Picker("Compression level", selection: $level) {
                        Text("Store (0)").tag(0)
                        Text("Fastest (1)").tag(1)
                        Text("Fast (3)").tag(3)
                        Text("Normal (5)").tag(5)
                        Text("Maximum (7)").tag(7)
                        Text("Ultra (9)").tag(9)
                    }
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                        if format == .sevenZip {
                            TextField("Method", text: $method)
                                .textFieldStyle(.roundedBorder)
                            Toggle("Encrypt file names", isOn: $encryptFileNames)
                        }
                        Text("Password protection isn’t available yet: macOS doesn’t let Mac7Zip read a password without exposing it to other processes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !validationMessages.isEmpty {
                    Section {
                        ForEach(validationMessages, id: \.self) { message in
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text(sources.count == 1 ? "1 item" : "\(sources.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: showAdvanced ? 460 : 380)
    }

    private func makeRequest() -> CompressionRequest {
        CompressionRequest(
            sources: sources,
            destination: directory.appendingPathComponent(name),
            format: format,
            level: level,
            method: format == .sevenZip ? method : nil,
            password: nil,
            encryptFileNames: format == .sevenZip ? encryptFileNames : false
        )
    }

    private func create() {
        let request = makeRequest()
        let errors = CompressionPlanner.validate(request)
        validationMessages = errors.map(Self.describe)
        guard errors.isEmpty else { return }
        onCreate(request)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        if panel.runModal() == .OK, let url = panel.url { directory = url }
    }

    private func renameForFormat(_ current: String, to newFormat: ArchiveFormat) -> String {
        let base = (current as NSString).deletingPathExtension
        return "\(base.isEmpty ? "Archive" : base).\(newFormat.rawValue)"
    }

    /// Human-readable validation messages.
    static func describe(_ error: CompressionPlanner.ValidationError) -> String {
        CompressionPlanner.describe(error)
    }
}
