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
                Spacer(minLength: 0)
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
}
