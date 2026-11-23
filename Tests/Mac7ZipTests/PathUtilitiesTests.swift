import XCTest
@testable import Mac7Zip

final class PathUtilitiesTests: XCTestCase {
    func testParentOfNestedFolder() {
        let url = URL(fileURLWithPath: "/Users/example/Documents/Projects")
        let parent = PathUtilities.parent(of: url)
        XCTAssertEqual(parent?.path, "/Users/example/Documents")
    }

    func testParentOfRootIsNil() {
        XCTAssertNil(PathUtilities.parent(of: URL(fileURLWithPath: "/")))
    }

    func testIsRoot() {
        XCTAssertTrue(PathUtilities.isRoot(URL(fileURLWithPath: "/")))
        XCTAssertFalse(PathUtilities.isRoot(URL(fileURLWithPath: "/Users")))
    }

    func testBreadcrumbs() {
        let url = URL(fileURLWithPath: "/Users/example/Documents")
        let crumbs = PathUtilities.breadcrumbs(for: url)
        XCTAssertEqual(crumbs.map(\.title), ["/", "Users", "example", "Documents"])
        XCTAssertEqual(crumbs.last?.url.path, "/Users/example/Documents")
    }

    func testBreadcrumbURLsAreNested() {
        let url = URL(fileURLWithPath: "/Applications/Utilities")
        let crumbs = PathUtilities.breadcrumbs(for: url)
        XCTAssertEqual(crumbs.map(\.url.path), ["/", "/Applications", "/Applications/Utilities"])
    }
}
