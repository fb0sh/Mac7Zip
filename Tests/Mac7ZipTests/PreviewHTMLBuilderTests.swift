import XCTest
@testable import Mac7Zip

final class PreviewHTMLBuilderTests: XCTestCase {
    private func item(_ path: String, dir: Bool = false) -> PreviewHTMLBuilder.Item {
        PreviewHTMLBuilder.Item(path: path, sizeText: dir ? "--" : "1 KB", dateText: "2026-01-01 00:00", isDirectory: dir)
    }

    func testRendersTreeWithSummary() {
        let html = PreviewHTMLBuilder.html(
            title: "a.zip", items: [item("docs/", dir: true), item("docs/x.txt")], summary: "2 项"
        )
        XCTAssertTrue(html.contains("x.txt"))
        XCTAssertTrue(html.contains("<details"))
        XCTAssertTrue(html.contains("2 项"))
    }

    func testEscapesHTML() {
        let html = PreviewHTMLBuilder.html(title: "x<y", items: [item("<script>.txt")], summary: "1 项")
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("x&lt;y"))
    }

    func testEmptyShowsMessage() {
        let html = PreviewHTMLBuilder.html(title: "e.zip", items: [], summary: "")
        XCTAssertTrue(html.contains("无法读取内容"))
    }

    func testRendersSystemIconWhenProvided() {
        let dataURL = "data:image/png;base64,AAAA"
        let iconItem = PreviewHTMLBuilder.Item(
            path: "a.jar", sizeText: "1 KB", dateText: "", isDirectory: false, iconDataURL: dataURL
        )
        let html = PreviewHTMLBuilder.html(title: "x.zip", items: [iconItem], summary: "")
        XCTAssertTrue(html.contains("src=\"\(dataURL)\""))
        XCTAssertTrue(html.contains("class=\"i\""))
    }

    func testOmitsImageWithoutIcon() {
        let html = PreviewHTMLBuilder.html(title: "x.zip", items: [item("a.txt")], summary: "")
        XCTAssertFalse(html.contains("data:image/png"))
        XCTAssertTrue(html.contains("a.txt"))
    }

    // MARK: - Tree shape

    func testNestedFoldersBecomeNestedDetails() {
        let items = [
            item("extensions/", dir: true),
            item("extensions/Burp/", dir: true),
            item("extensions/Burp/a.jar"),
        ]
        let html = PreviewHTMLBuilder.html(title: "x.7z", items: items, summary: "")
        // Outer folder opens by default; the nested one must stay collapsed.
        XCTAssertTrue(html.contains("<details open>"))
        XCTAssertTrue(html.contains("<details>"))
        XCTAssertTrue(html.contains("a.jar"))
    }

    func testImplicitParentFoldersAreSynthesised() {
        // Only the leaf is listed; "docs/" must still appear as a folder.
        let html = PreviewHTMLBuilder.html(title: "x.zip", items: [item("docs/x.txt")], summary: "")
        XCTAssertTrue(html.contains("docs/"))
        XCTAssertTrue(html.contains("<details open>"))
    }

    func testFoldersSortBeforeFiles() {
        let nodes = PreviewHTMLBuilder.tree(from: [item("b.txt"), item("a/", dir: true)])
        XCTAssertEqual(nodes.map(\.name), ["a", "b.txt"])
        XCTAssertTrue(nodes[0].isDirectory)
    }
}
