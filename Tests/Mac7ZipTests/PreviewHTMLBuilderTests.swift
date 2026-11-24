import XCTest
@testable import Mac7Zip

final class PreviewHTMLBuilderTests: XCTestCase {
    private func item(_ path: String, dir: Bool = false) -> PreviewHTMLBuilder.Item {
        PreviewHTMLBuilder.Item(path: path, sizeText: dir ? "--" : "1 KB", dateText: "2026-01-01 00:00", isDirectory: dir)
    }

    func testRendersRowsAndSummary() {
        let html = PreviewHTMLBuilder.html(title: "a.zip", items: [item("docs/"), item("docs/x.txt")], summary: "2 项")
        XCTAssertTrue(html.contains("docs/x.txt"))
        XCTAssertTrue(html.contains("<table>"))
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
}
