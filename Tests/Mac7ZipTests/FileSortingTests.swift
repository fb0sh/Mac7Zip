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

final class FileSortingDirectoryFirstTests: XCTestCase {
    private func item(_ name: String, dir: Bool, size: Int64 = 0) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/t/\(name)"), name: name, isDirectory: dir,
                 size: size, modificationDate: nil, kind: dir ? "Folder" : "File")
    }

    func testDirectoriesFirstAscending() {
        let items = [item("a.txt", dir: false), item("zeta", dir: true), item("b.txt", dir: false)]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .name, ascending: true))
        XCTAssertTrue(sorted.first?.isDirectory ?? false)
        XCTAssertEqual(sorted.map(\.name), ["zeta", "a.txt", "b.txt"])
    }

    func testDirectoriesFirstDescending() {
        let items = [item("zeta", dir: true), item("a.txt", dir: false), item("alpha", dir: true)]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .name, ascending: false))
        XCTAssertEqual(sorted.prefix(2).map(\.isDirectory), [true, true], "Folders stay first even when descending")
        XCTAssertEqual(sorted.last?.name, "a.txt")
    }

    func testDirectoriesFirstBySize() {
        let items = [item("big.bin", dir: false, size: 999), item("folder", dir: true, size: 0)]
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .size, ascending: true))
        XCTAssertTrue(sorted.first?.isDirectory ?? false)
    }
}
