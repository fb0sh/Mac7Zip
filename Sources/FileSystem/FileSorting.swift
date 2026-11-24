import Foundation

/// Pure sorting logic for file listings, kept free of UI and disk access so it
/// can be unit tested in isolation.
enum FileSorting {
    static func sorted(_ items: [FileItem], by descriptor: FileSortDescriptor) -> [FileItem] {
        items.sorted { lhs, rhs in
            // Finder convention: folders always group before files, regardless of
            // sort direction, then sort within each group.
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            let order = compare(lhs, rhs, field: descriptor.field)
            if order == .orderedSame {
                // Stable, predictable tie-break by name.
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return descriptor.ascending
                ? order == .orderedAscending
                : order == .orderedDescending
        }
    }

    private static func compare(_ lhs: FileItem, _ rhs: FileItem, field: FileSortField) -> ComparisonResult {
        switch field {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .size:
            if lhs.size == rhs.size { return .orderedSame }
            return lhs.size < rhs.size ? .orderedAscending : .orderedDescending
        case .kind:
            return lhs.kind.localizedStandardCompare(rhs.kind)
        case .date:
            let left = lhs.modificationDate ?? .distantPast
            let right = rhs.modificationDate ?? .distantPast
            if left == right { return .orderedSame }
            return left < right ? .orderedAscending : .orderedDescending
        }
    }
}
