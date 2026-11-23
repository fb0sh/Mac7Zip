import XCTest
@testable import Mac7Zip

final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "Mac7ZipSettings-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaults() {
        let settings = AppSettings()
        XCTAssertEqual(settings.activation, .open)
        XCTAssertTrue(settings.extractSubfolderByDefault)
        XCTAssertTrue(settings.isValid)
        XCTAssertEqual(settings.extractionLimits.maxTotalBytes, 4 * 1024 * 1024 * 1024)
    }

    func testActivationRoundTrips() {
        XCTAssertEqual(ArchiveActivation(rawValue: "extract"), .extract)
        XCTAssertEqual(ArchiveActivation.open.displayName, "Open in Mac7Zip")
        XCTAssertEqual(ArchiveActivation.extract.displayName, "Extract to <name>/ folder")
    }

    func testInvalidLimitsDetected() {
        var settings = AppSettings()
        settings.maxTotalBytes = 0
        settings.maxExpansionRatio = 0
        settings.maxEntryCount = 0
        XCTAssertFalse(settings.isValid)
        XCTAssertEqual(settings.validationErrors.count, 3)
    }

    func testPersistence() {
        let store = SettingsStore(defaults: defaults, key: "s")
        store.settings.activation = .extract
        store.settings.maxExpansionRatio = 50

        let reloaded = SettingsStore(defaults: defaults, key: "s")
        XCTAssertEqual(reloaded.settings.activation, .extract)
        XCTAssertEqual(reloaded.settings.maxExpansionRatio, 50)
    }

    func testReset() {
        let store = SettingsStore(defaults: defaults, key: "s")
        store.settings.activation = .extract
        store.reset()
        XCTAssertEqual(store.settings.activation, .open)
    }

    func testLimitsBridgeToExtractionLimits() {
        var settings = AppSettings()
        settings.maxTotalBytes = 1024
        settings.maxExpansionRatio = 10
        settings.maxEntryCount = 5
        let limits = settings.extractionLimits
        XCTAssertEqual(limits.maxTotalBytes, 1024)
        XCTAssertEqual(limits.maxExpansionRatio, 10)
        XCTAssertEqual(limits.maxEntryCount, 5)
    }
}

final class NotificationPolicyTests: XCTestCase {
    func testDeniedNeverDelivers() {
        XCTAssertFalse(NotificationPolicy.shouldDeliver(permission: .denied, userEnabled: true))
    }
    func testNotDeterminedNeverDelivers() {
        XCTAssertFalse(NotificationPolicy.shouldDeliver(permission: .notDetermined, userEnabled: true))
    }
    func testAuthorizedDeliversWhenEnabled() {
        XCTAssertTrue(NotificationPolicy.shouldDeliver(permission: .authorized, userEnabled: true))
        XCTAssertFalse(NotificationPolicy.shouldDeliver(permission: .authorized, userEnabled: false))
    }
    func testProvisionalDelivers() {
        XCTAssertTrue(NotificationPolicy.shouldDeliver(permission: .provisional, userEnabled: true))
    }
}

@MainActor
final class RestorationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var dir: URL!

    override func setUpWithError() throws {
        suiteName = "Mac7ZipRestore-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("Mac7ZipRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testRecordAndRestore() {
        let store = RestorationStore(defaults: defaults, key: "last")
        store.record(dir)
        XCTAssertEqual(store.restorableURL()?.standardizedFileURL.path, dir.standardizedFileURL.path)

        let reloaded = RestorationStore(defaults: defaults, key: "last")
        XCTAssertEqual(reloaded.restorableURL()?.standardizedFileURL.path, dir.standardizedFileURL.path)
    }

    func testMissingPathIsNotRestorable() {
        let store = RestorationStore(defaults: defaults, key: "last")
        store.record(dir.appendingPathComponent("gone"))
        XCTAssertNil(store.restorableURL())
    }

    func testClear() {
        let store = RestorationStore(defaults: defaults, key: "last")
        store.record(dir)
        store.clear()
        XCTAssertNil(store.restorableURL())
    }
}

final class ArchiveDocumentTypesTests: XCTestCase {
    func testHandlesCommonExtensions() {
        for ext in ["7z", "zip", "tar", "gz", "rar"] {
            XCTAssertTrue(ArchiveDocumentTypes.handles(pathExtension: ext), ext)
        }
        XCTAssertTrue(ArchiveDocumentTypes.handles(pathExtension: "ZIP"))
        XCTAssertFalse(ArchiveDocumentTypes.handles(pathExtension: "txt"))
    }
    func testUtiListNonEmpty() {
        XCTAssertFalse(ArchiveDocumentTypes.utis.isEmpty)
        XCTAssertTrue(ArchiveDocumentTypes.extensions.contains("7z"))
    }
}
