import XCTest
@testable import Mac7Zip

final class FileSortingTests: XCTestCase {
    private func makeItem(
        name: String,
        size: Int64 = 0,
        isDirectory: Bool = false,
        modified: TimeInterval? = nil
    ) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: isDirectory,
            size: size,
            modificationDate: modified.map { Date(timeIntervalSince1970: $0) },
            kind: isDirectory ? "Folder" : "Document"
        )
    }

    func testSortsByNameAscending() {
        let items = [makeItem(name: "banana"), makeItem(name: "apple"), makeItem(name: "cherry")]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .name, ascending: true))
        XCTAssertEqual(sorted.map(\.name), ["apple", "banana", "cherry"])
    }

    func testSortsByNameDescending() {
        let items = [makeItem(name: "banana"), makeItem(name: "apple"), makeItem(name: "cherry")]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .name, ascending: false))
        XCTAssertEqual(sorted.map(\.name), ["cherry", "banana", "apple"])
    }

    func testSortsBySizeAscending() {
        let items = [
            makeItem(name: "big", size: 5_000),
            makeItem(name: "small", size: 10),
            makeItem(name: "medium", size: 500),
        ]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .size, ascending: true))
        XCTAssertEqual(sorted.map(\.name), ["small", "medium", "big"])
    }

    func testSortsBySizeDescending() {
        let items = [
            makeItem(name: "big", size: 5_000),
            makeItem(name: "small", size: 10),
            makeItem(name: "medium", size: 500),
        ]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .size, ascending: false))
        XCTAssertEqual(sorted.map(\.name), ["big", "medium", "small"])
    }

    func testSortsByModificationDate() {
        let items = [
            makeItem(name: "newest", modified: 300),
            makeItem(name: "oldest", modified: 100),
            makeItem(name: "middle", modified: 200),
        ]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .date, ascending: true))
        XCTAssertEqual(sorted.map(\.name), ["oldest", "middle", "newest"])
    }

    func testEqualToSortsSameCount() {
        let items = [makeItem(name: "b"), makeItem(name: "a")]
        let sorted = FileSorting.sorted(items, by: .default)
        XCTAssertEqual(sorted.count, items.count)
    }
}
