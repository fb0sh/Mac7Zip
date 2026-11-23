import XCTest
@testable import Mac7Zip

/// Advisory performance benchmarks (see SPEC-REL gating policy). Correctness is
/// asserted; timing is recorded via `measure` and is informational in CI.
final class PerformanceBenchmarkTests: XCTestCase {
    private func makeItems(_ count: Int) -> [FileItem] {
        (0..<count).map { index in
            FileItem(
                url: URL(fileURLWithPath: "/tmp/file\(index).txt"),
                name: "file\(index).txt",
                isDirectory: false,
                size: Int64(index * 7 % 100_000),
                modificationDate: Date(timeIntervalSince1970: TimeInterval(index)),
                kind: "TXT document"
            )
        }
    }

    func testSortTenThousandItems() {
        let items = makeItems(10_000)
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .size, ascending: true))
        XCTAssertEqual(sorted.count, 10_000)
        XCTAssertLessThanOrEqual(sorted.first?.size ?? -1, sorted.last?.size ?? -1)

        measure {
            _ = FileSorting.sorted(items, by: FileSortDescriptor(field: .size, ascending: true))
        }
    }

    func testSortOneHundredThousandItems() {
        let items = makeItems(100_000)
        let sorted = FileSorting.sorted(items, by: FileSortDescriptor(field: .name, ascending: true))
        XCTAssertEqual(sorted.count, 100_000)
        XCTAssertEqual(sorted.first?.name, "file0.txt")
        measure {
            _ = FileSorting.sorted(items, by: FileSortDescriptor(field: .size, ascending: false))
        }
    }

    func testFilterAndSortLargeListing() {
        let items = makeItems(100_000)
        let filtered = items.filter { !$0.isDirectory && $0.size > 1000 }
        let sorted = FileSorting.sorted(filtered, by: FileSortDescriptor(field: .size, ascending: true))
        XCTAssertFalse(sorted.isEmpty)
        XCTAssertLessThanOrEqual(sorted.first?.size ?? -1, sorted.last?.size ?? -1)
        measure {
            _ = FileSorting.sorted(items.filter { $0.size % 2 == 0 }, by: FileSortDescriptor(field: .name, ascending: true))
        }
    }
}
}
