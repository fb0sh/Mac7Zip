import AppKit
import SwiftUI

/// Native extract-options sheet (SPEC-AE FR-AE-12 / SPEC-AB FR-AB-11).
///
/// The password field is deliberately **disabled** with an explanation: 7zz's
/// password prompt is console-bound, so Mac7Zip cannot read a password securely
/// (see ADR-005). Refusing is better than silently exposing it in `ps`.
struct ExtractOptionsSheet: View {
    let archiveName: String
    let defaultDestination: URL
    let onExtract: (ExtractOptions) -> Void
    let onCancel: () -> Void

    @State private var destination: URL
    @State private var createSubfolder: Bool = true
    @State private var subfolderName: String
    @State private var pathMode: ExtractPathMode = .full
    @State private var eliminateDuplicateRoot: Bool = false
    @State private var overwriteMode: OverwriteMode = .ask
    @State private var restorePermissions: Bool = false

    init(
        archiveName: String,
        defaultDestination: URL,
        onExtract: @escaping (ExtractOptions) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.archiveName = archiveName
        self.defaultDestination = defaultDestination
        self.onExtract = onExtract
        self.onCancel = onCancel
        _destination = State(initialValue: defaultDestination)
        _subfolderName = State(initialValue: Self.baseName(for: archiveName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    LabeledContent("Extract To") {
                        HStack {
                            Text(destination.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Button("Choose…") { chooseDestination() }
                        }
                    }
                    Toggle("Extract into subfolder", isOn: $createSubfolder)
                    if createSubfolder {
                        TextField("Subfolder name", text: $subfolderName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Options") {
                    Picker("Path mode", selection: $pathMode) {
                        Text("Full paths").tag(ExtractPathMode.full)
                        Text("Relative").tag(ExtractPathMode.relative)
                    }
                    Toggle("Eliminate duplicate root folder", isOn: $eliminateDuplicateRoot)
                    Picker("Overwrite", selection: $overwriteMode) {
                        Text("Ask before overwriting").tag(OverwriteMode.ask)
                        Text("Overwrite").tag(OverwriteMode.overwrite)
                        Text("Skip existing").tag(OverwriteMode.skip)
                        Text("Auto-rename").tag(OverwriteMode.rename)
                    }
                    Toggle("Restore file security settings", isOn: $restorePermissions)
                }

                Section("Password") {
                    Text("Password-protected archives can’t be opened yet: macOS doesn’t let Mac7Zip read a password without exposing it to other processes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Extract") { onExtract(makeOptions()) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(createSubfolder && subfolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 460)
    }

    private func makeOptions() -> ExtractOptions {
        ExtractOptions(
            password: nil,
            entries: nil,
            destination: destination,
            createSubfolder: createSubfolder ? subfolderName : nil,
            pathMode: pathMode,
            eliminateDuplicateRoot: eliminateDuplicateRoot,
            overwriteMode: overwriteMode,
            restorePermissions: restorePermissions
        )
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = destination
        if panel.runModal() == .OK, let url = panel.url {
            destination = url
        }
    }

    /// "photos.tar.gz" → "photos"
    static func baseName(for archiveName: String) -> String {
        var name = archiveName
        for suffix in [".tar.gz", ".tgz", ".7z", ".zip", ".tar", ".gz", ".bz2", ".xz", ".rar"] {
            if name.lowercased().hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name.isEmpty ? "Extracted" : name
    }
}
