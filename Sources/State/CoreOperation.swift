import Foundation

/// The seven core 7-Zip file-manager operations (see docs/reference/7zip/ui-reference.md §A).
/// Shared by the toolbar and the row context menu so both stay consistent and the
/// availability rules are unit-testable.
enum CoreOperation: String, CaseIterable, Identifiable, Sendable {
    case add
    case extract
    case test
    case copy
    case move
    case delete
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .add: return "Add"
        case .extract: return "Extract"
        case .test: return "Test"
        case .copy: return "Copy"
        case .move: return "Move"
        case .delete: return "Delete"
        case .info: return "Info"
        }
    }

    var systemImage: String {
        switch self {
        case .add: return "plus"
        case .extract: return "square.and.arrow.up"
        case .test: return "checkmark.seal"
        case .copy: return "doc.on.doc"
        case .move: return "folder"
        case .delete: return "trash"
        case .info: return "info.circle"
        }
    }

    /// Whether this operation acts on the current selection.
    var requiresSelection: Bool {
        switch self {
        case .copy, .move, .delete: return true
        default: return false
        }
    }

    /// Availability given the current browsing state. Pure → unit-testable.
    static func isEnabled(
        _ operation: CoreOperation,
        isInsideArchive: Bool,
        canModify: Bool,
        hasSelection: Bool,
        hasItems: Bool
    ) -> Bool {
        switch operation {
        case .add:
            return !isInsideArchive
        case .extract:
            return isInsideArchive && hasItems
        case .test:
            return isInsideArchive
        case .copy, .move:
            return canModify && hasSelection
        case .delete:
            return canModify && hasSelection
        case .info:
            return !isInsideArchive
        }
    }
}
