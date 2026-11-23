import Foundation

/// The columns a file listing can be sorted by.
enum FileSortField: String, CaseIterable, Sendable {
    case name
    case size
    case kind
    case date

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .size: return "Size"
        case .kind: return "Kind"
        case .date: return "Date Modified"
        }
    }
}

/// The current sort configuration for the file browser.
struct FileSortDescriptor: Equatable, Sendable {
    var field: FileSortField
    var ascending: Bool

    static let `default` = FileSortDescriptor(field: .name, ascending: true)
}
