import XCTest
@testable import Mac7Zip

@MainActor
final class FavouritesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "Mac7ZipTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsAreSeeded() {
        let store = FavouritesStore(defaults: defaults, key: "fav")
        XCTAssertEqual(store.favourites.map(\.name), ["Home", "Desktop", "Documents", "Downloads", "Applications"])
    }

    func testAddPersists() {
        let store = FavouritesStore(defaults: defaults, key: "fav")
        let custom = URL(fileURLWithPath: "/tmp/my-project")
        XCTAssertTrue(store.add(url: custom))
        XCTAssertEqual(store.favourites.last?.path, custom.standardizedFileURL.path)

        let reloaded = FavouritesStore(defaults: defaults, key: "fav")
        XCTAssertTrue(reloaded.favourites.contains { $0.path == custom.standardizedFileURL.path })
    }

    func testAddDuplicateIgnored() {
        let store = FavouritesStore(defaults: defaults, key: "fav")
        let url = URL(fileURLWithPath: "/tmp/x")
        XCTAssertTrue(store.add(url: url))
        XCTAssertFalse(store.add(url: url))
    }

    func testRemove() {
        let store = FavouritesStore(defaults: defaults, key: "fav")
        let first = store.favourites[0]
        store.remove(first)
        XCTAssertFalse(store.favourites.contains { $0.path == first.path })
        let reloaded = FavouritesStore(defaults: defaults, key: "fav")
        XCTAssertFalse(reloaded.favourites.contains { $0.path == first.path })
    }

    func testIsFavourite() {
        let store = FavouritesStore(defaults: defaults, key: "fav")
        XCTAssertTrue(store.isFavourite(FileLocations.home))
        XCTAssertFalse(store.isFavourite(URL(fileURLWithPath: "/nope/elsewhere")))
    }

    func testResetToDefaults() {
        let store = FavouritesStore(defaults: defaults, key: "fav")
        store.add(url: URL(fileURLWithPath: "/tmp/custom"))
        store.resetToDefaults()
        XCTAssertEqual(store.favourites.count, 5)
    }
}

@MainActor
final class DualPaneControllerTests: XCTestCase {
    func testInitiallySinglePane() {
        let controller = DualPaneController()
        XCTAssertFalse(controller.isDualPane)
        XCTAssertEqual(controller.activePane, 0)
    }

    func testToggleOnAndOff() {
        let controller = DualPaneController()
        controller.toggle()
        XCTAssertTrue(controller.isDualPane)
        controller.setActive(1)
        XCTAssertEqual(controller.activePane, 1)
        controller.toggle()
        XCTAssertFalse(controller.isDualPane)
        XCTAssertEqual(controller.activePane, 0, "Turning dual-pane off resets to the primary pane")
    }

    func testSetActiveIgnoredWhenSinglePane() {
        let controller = DualPaneController()
        controller.setActive(1)
        XCTAssertEqual(controller.activePane, 0)
    }

    func testSetActiveIgnoresInvalidIndex() {
        let controller = DualPaneController(isDualPane: true)
        controller.setActive(5)
        XCTAssertEqual(controller.activePane, 0)
    }
}
