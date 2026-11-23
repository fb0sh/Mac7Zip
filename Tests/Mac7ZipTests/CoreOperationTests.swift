import XCTest
@testable import Mac7Zip

final class CoreOperationTests: XCTestCase {
    func testSevenCoreOperationsInReferenceOrder() {
        XCTAssertEqual(CoreOperation.allCases.map(\.title),
                       ["Add", "Extract", "Test", "Copy", "Move", "Delete", "Info"])
    }

    func testAvailabilityRealFolderWithSelection() {
        let s = (inside: false, modify: true, selection: true, items: true)
        XCTAssertTrue(CoreOperation.isEnabled(.add, isInsideArchive: s.inside, canModify: s.modify, hasSelection: s.selection, hasItems: s.items))
        XCTAssertTrue(CoreOperation.isEnabled(.copy, isInsideArchive: s.inside, canModify: s.modify, hasSelection: s.selection, hasItems: s.items))
        XCTAssertTrue(CoreOperation.isEnabled(.delete, isInsideArchive: s.inside, canModify: s.modify, hasSelection: s.selection, hasItems: s.items))
        XCTAssertFalse(CoreOperation.isEnabled(.extract, isInsideArchive: s.inside, canModify: s.modify, hasSelection: s.selection, hasItems: s.items))
        XCTAssertFalse(CoreOperation.isEnabled(.test, isInsideArchive: s.inside, canModify: s.modify, hasSelection: s.selection, hasItems: s.items))
    }

    func testAvailabilityInsideArchive() {
        XCTAssertTrue(CoreOperation.isEnabled(.extract, isInsideArchive: true, canModify: false, hasSelection: true, hasItems: true))
        XCTAssertTrue(CoreOperation.isEnabled(.test, isInsideArchive: true, canModify: false, hasSelection: false, hasItems: true))
        XCTAssertFalse(CoreOperation.isEnabled(.add, isInsideArchive: true, canModify: false, hasSelection: true, hasItems: true))
        XCTAssertFalse(CoreOperation.isEnabled(.copy, isInsideArchive: true, canModify: false, hasSelection: true, hasItems: true))
    }

    func testExtractNeedsItems() {
        XCTAssertFalse(CoreOperation.isEnabled(.extract, isInsideArchive: true, canModify: false, hasSelection: false, hasItems: false))
    }

    func testSelectionRequirementFlags() {
        XCTAssertTrue(CoreOperation.copy.requiresSelection)
        XCTAssertTrue(CoreOperation.move.requiresSelection)
        XCTAssertTrue(CoreOperation.delete.requiresSelection)
        XCTAssertFalse(CoreOperation.add.requiresSelection)
        XCTAssertFalse(CoreOperation.info.requiresSelection)
    }

    func testEveryOperationHasIcon() {
        for op in CoreOperation.allCases {
            XCTAssertFalse(op.systemImage.isEmpty, "\(op) needs an SF Symbol")
        }
    }
}
