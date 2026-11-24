import AppKit

/// Native prompts for copy/move/duplicate, including conflict resolution.
///
/// A destination folder is chosen with `NSOpenPanel`; existing targets prompt for
/// replace / skip / keep-both (with "apply to all" semantics via the chosen policy).
@MainActor
enum TransferViewActions {

    static func copySelection(in model: BrowserStore) { transfer(.copy, in: model) }
    static func moveSelection(in model: BrowserStore) { transfer(.move, in: model) }
    static func duplicateSelection(in model: BrowserStore) {
        guard !model.selectedItems.isEmpty else { return }
        Task { await model.transfer(kind: .duplicate, to: model.currentDirectory, policy: .keepBoth) }
    }

    private static func transfer(_ kind: FileTransferRequest.Kind, in model: BrowserStore) {
        guard model.canModify, !model.selectedItems.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = kind == .move ? "Move Here" : "Copy Here"
        panel.message = kind == .move ? "Choose a destination folder to move to" : "Choose a destination folder to copy to"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let policy = conflictPolicy(kind: kind, count: model.selectedItems.count)
        guard let policy else { return }
        Task { await model.transfer(kind: kind, to: destination, policy: policy) }
    }

    /// Asks how to handle name clashes; returns `nil` when the user cancels.
    private static func conflictPolicy(kind: FileTransferRequest.Kind, count: Int) -> ConflictPolicy? {
        let alert = NSAlert()
        alert.messageText = "If a file already exists"
        alert.informativeText = "Choose what to do when an item with the same name is already in the destination."
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Skip")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .keepBoth
        case .alertSecondButtonReturn: return .replace
        case .alertThirdButtonReturn: return .skip
        default: return nil
        }
    }
}
