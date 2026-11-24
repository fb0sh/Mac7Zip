import SwiftUI

/// Breadcrumb path bar with an optional manual-entry mode.
struct PathBarView: View {
    @EnvironmentObject private var model: FileBrowserModel
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                TextField("Path", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit(commit)
                Button("Go", action: commit)
                Button("Cancel") { isEditing = false }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if model.isInsideArchive {
                            Button(model.archiveURL?.lastPathComponent ?? "Archive") {
                                model.navigateToArchivePath("")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            ForEach(Array(archiveCrumbs.enumerated()), id: \.offset) { _, crumb in
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Button(crumb.title) { model.navigateToArchivePath(crumb.path) }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(PathUtilities.breadcrumbs(for: model.currentDirectory), id: \.url) { crumb in
                                Button(crumb.title) { model.navigate(to: crumb.url) }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                if crumb.url != model.currentDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if !model.isInsideArchive {
                    Button {
                        draft = model.currentDirectory.path
                        isEditing = true
                        fieldFocused = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Edit Path")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isEditing = false
            return
        }
        guard let target = model.resolveNavigationTarget(trimmed) else {
            isEditing = false
            return
        }
        model.navigate(to: target)
        isEditing = false
    }

    private var archiveCrumbs: [(title: String, path: String)] {
        let parts = ArchiveFileSystemProvider.breadcrumbs(prefix: model.archiveInternalPath ?? "")
        var accumulated: [String] = []
        var result: [(title: String, path: String)] = []
        for part in parts {
            accumulated.append(part)
            result.append((part, accumulated.joined(separator: "/")))
        }
        return result
    }
}
