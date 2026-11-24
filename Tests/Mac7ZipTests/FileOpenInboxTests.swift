import XCTest
@testable import Mac7Zip

@MainActor
final class FileOpenInboxTests: XCTestCase {
    func testClaimOnceOnly() {
        let inbox = FileOpenInbox.shared
        let url = URL(fileURLWithPath: "/tmp/a.zip")
        inbox.enqueue(url)
        let item = inbox.pendingOpen!
        XCTAssertEqual(inbox.claim(item.id), url)
        XCTAssertNil(inbox.claim(item.id), "second claim must not return the same request")
        XCTAssertNil(inbox.pendingOpen)
    }

    func testStaleIdDoesNotClaim() {
        let inbox = FileOpenInbox.shared
        inbox.enqueue(URL(fileURLWithPath: "/tmp/a.zip"))
        XCTAssertNil(inbox.claim(UUID()))
        XCTAssertNotNil(inbox.pendingOpen)
    }

    func testNewEnqueueWins() {
        let inbox = FileOpenInbox.shared
        inbox.enqueue(URL(fileURLWithPath: "/tmp/old.zip"))
        let old = inbox.pendingOpen!.id
        inbox.enqueue(URL(fileURLWithPath: "/tmp/new.zip"))
        XCTAssertNil(inbox.claim(old))
        let current = inbox.pendingOpen!
        XCTAssertEqual(inbox.claim(current.id)?.lastPathComponent, "new.zip")
    }
}
