import XCTest
@testable import Mac7Zip

@MainActor
final class FileOpenInboxTests: XCTestCase {
    @MainActor func testEnqueueAndClaimOnce() {
        let inbox = FileOpenInbox.shared
        inbox.pendingOpen = nil
        let url = URL(fileURLWithPath: "/tmp/a.zip")
        inbox.enqueue(url)
        let item = inbox.pendingOpen!
        XCTAssertEqual(inbox.claim(item.id), url)
        XCTAssertNil(inbox.claim(item.id), "second claim must not return the same request")
        XCTAssertNil(inbox.pendingOpen)
    }

    @MainActor func testStaleIdDoesNotClaim() {
        let inbox = FileOpenInbox.shared
        inbox.pendingOpen = nil
        inbox.enqueue(URL(fileURLWithPath: "/tmp/a.zip"))
        XCTAssertNil(inbox.claim(UUID()))
        XCTAssertNotNil(inbox.pendingOpen)
    }

    @MainActor func testNonFileURLIgnored() {
        let inbox = FileOpenInbox.shared
        inbox.pendingOpen = nil
        inbox.enqueue(URL(string: "https://example.com")!)
        XCTAssertNil(inbox.pendingOpen)
    }
}

private actor FakeNotifier: NotificationDispatching {
    var permission: NotificationPermission
    let grantsOnRequest: NotificationPermission
    var requested = false
    private(set) var posted: [(String, String)] = []

    init(permission: NotificationPermission, grantsOnRequest: NotificationPermission? = nil) {
        self.permission = permission
        self.grantsOnRequest = grantsOnRequest ?? permission
    }

    func authorizationStatus() async -> NotificationPermission { permission }
    func requestAuthorization() async -> NotificationPermission {
        requested = true
        permission = grantsOnRequest
        return permission
    }
    func post(title: String, body: String) async { posted.append((title, body)) }

    func postedCount() -> Int { posted.count }
    func didRequest() -> Bool { requested }
}

@MainActor
final class NotificationCoordinatorTests: XCTestCase {
    private func record(_ state: TaskState) -> TaskRecord {
        TaskRecord(id: UUID(), kind: .copy, title: "Copy 3 items", state: state)
    }

    func testDisabledDoesNothing() async {
        let fake = FakeNotifier(permission: .authorized)
        let coordinator = NotificationCoordinator(service: fake)
        await coordinator.notifyTaskFinished(record: record(.succeeded), enabled: false)
        let count = await fake.postedCount()
        XCTAssertEqual(count, 0)
    }

    func testDeniedDoesNotPost() async {
        let fake = FakeNotifier(permission: .denied)
        let coordinator = NotificationCoordinator(service: fake)
        await coordinator.notifyTaskFinished(record: record(.succeeded), enabled: true)
        let count = await fake.postedCount()
        XCTAssertEqual(count, 0)
    }

    func testAuthorizedPostsOnSuccessAndFailure() async {
        let fake = FakeNotifier(permission: .authorized)
        let coordinator = NotificationCoordinator(service: fake)
        await coordinator.notifyTaskFinished(record: record(.succeeded), enabled: true)
        await coordinator.notifyTaskFinished(record: record(.failed), enabled: true)
        let count = await fake.postedCount()
        XCTAssertEqual(count, 2)
    }

    func testNotDeterminedRequestsThenPosts() async {
        let fake = FakeNotifier(permission: .notDetermined, grantsOnRequest: .authorized)
        let coordinator = NotificationCoordinator(service: fake)
        await coordinator.notifyTaskFinished(record: record(.succeeded), enabled: true)
        let requested = await fake.didRequest()
        XCTAssertTrue(requested)
        let count = await fake.postedCount()
        XCTAssertEqual(count, 1)
    }

    func testStatusMapping() {
        XCTAssertEqual(SystemNotificationService.map(.authorized), .authorized)
        XCTAssertEqual(SystemNotificationService.map(.denied), .denied)
        XCTAssertEqual(SystemNotificationService.map(.provisional), .provisional)
        XCTAssertEqual(SystemNotificationService.map(.notDetermined), .notDetermined)
    }
}

final class BundleConfigTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) {
                return dir
            }
        }
        return dir
    }

    func testNoticeFileExists() {
        let notice = repoRoot.appendingPathComponent("Support/NOTICE.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: notice.path), "NOTICE.md must be bundled")
        let text = (try? String(contentsOf: notice, encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("LGPL"))
        XCTAssertTrue(text.lowercased().contains("unrar"))
    }

    func testProjectDeclaresDocumentTypes() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("CFBundleDocumentTypes"))
        XCTAssertTrue(yml.contains("org.7-zip.7-zip-archive"))
        XCTAssertTrue(yml.contains("CFBundleURLSchemes"))
    }
}
