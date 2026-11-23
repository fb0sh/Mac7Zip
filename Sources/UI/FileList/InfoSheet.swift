import AppKit
import SwiftUI

/// Native "Get Info" panel: metadata, permissions and Finder tags (TKT-M4-06/08).
struct InfoSheet: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var metadata: FileMetadata?
    @State private var errorMessage: String?
    @State private var selectedPermissions: UInt16 = 0o644
    @State private var tagsText: String = ""

    private let service = FileMetadataService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let metadata {
                Form {
                    Section {
                        LabeledContent("Name", value: metadata.name)
                        LabeledContent("Kind", value: metadata.kind)
                        if metadata.isDirectory {
                            LabeledContent("Items", value: "\(metadata.itemCount ?? 0)")
                        } else {
                            LabeledContent("Size", value: FileSizeFormatter.string(fromByteCount: metadata.size))
                        }
                        if let created = metadata.creationDate {
                            LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let modified = metadata.modificationDate {
                            LabeledContent("Modified", value: modified.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let target = metadata.linkTarget {
                            LabeledContent("Link Target", value: target)
                        }
                    }

                    Section("Ownership & Permissions") {
                        if let owner = metadata.ownerName {
                            LabeledContent("Owner", value: owner)
                        }
                        if let group = metadata.groupName {
                            LabeledContent("Group", value: group)
                        }
                        LabeledContent("Permissions") {
                            HStack {
                                Text(metadata.permissionString ?? "—")
                                    .monospaced()
                                Picker("", selection: $selectedPermissions) {
                                    Text("Read & Write (644)").tag(UInt16(0o644))
                                    Text("Read only (444)").tag(UInt16(0o444))
                                    Text("Read & Execute (755)").tag(UInt16(0o755))
                                    Text("No access (000)").tag(UInt16(0o000))
                                }
                                .labelsHidden()
                                .frame(width: 200)
                                Button("Apply") { applyPermissions() }
                                    .disabled(selectedPermissions == metadata.posixPermissions)
                            }
                        }
                    }

                    Section("Tags") {
                        TextField("Comma-separated tags", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                        Button("Save Tags") { applyTags() }
                    }
                }
                .formStyle(.grouped)
            } else if let errorMessage {
                ContentUnavailableView("Couldn’t Read Info", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(height: 220)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            }

            Divider()
            HStack {
                Spacer()
                Button("Done", action: onDismiss).keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460, height: 520)
        .task { load() }
    }

    private func load() {
        do {
            let loaded = try service.metadata(for: url)
            metadata = loaded
            selectedPermissions = loaded.posixPermissions ?? 0o644
            tagsText = loaded.finderTags.joined(separator: ", ")
        } catch let error as FileMetadataError {
            errorMessage = describe(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyPermissions() {
        do {
            try service.setPermissions(selectedPermissions, for: url)
            load()
        } catch let error as FileMetadataError {
            errorMessage = describe(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyTags() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        do {
            try FinderTagService.setTags(tags, for: url)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func describe(_ error: FileMetadataError) -> String {
        switch error {
        case .notFound(let name): return "“\(name)” no longer exists."
        case .permissionDenied(let name): return "You don’t have permission to change “\(name)”."
        case .failed(let message): return message
        }
    }
}
