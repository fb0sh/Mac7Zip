import XCTest
@testable import Mac7Zip

final class AdvancedCompressionOptionsTests: XCTestCase {
    func testEmptyOptionsProduceOnlyPathMode() {
        let args = AdvancedCompressionValidator.arguments(for: AdvancedCompressionOptions(), format: .sevenZip)
        XCTAssertEqual(args, ["-spr0"])
    }

    func testSevenZipAdvancedSwitches() {
        var options = AdvancedCompressionOptions()
        options.dictionarySize = "64m"
        options.wordSize = "64"
        options.solidBlockSize = "8g"
        options.threadCount = 4
        options.volumeSize = "100m"
        let args = AdvancedCompressionValidator.arguments(for: options, format: .sevenZip)
        XCTAssertTrue(args.contains("-md=64m"))
        XCTAssertTrue(args.contains("-mfb=64"))
        XCTAssertTrue(args.contains("-ms=8g"))
        XCTAssertTrue(args.contains("-mmt=4"))
        XCTAssertTrue(args.contains("-v100m"))
    }

    func testZipIgnoresSevenZipOnlySwitches() {
        var options = AdvancedCompressionOptions()
        options.dictionarySize = "64m"
        options.wordSize = "64"
        options.solidBlockSize = "8g"
        let args = AdvancedCompressionValidator.arguments(for: options, format: .zip)
        XCTAssertFalse(args.contains { $0.hasPrefix("-md=") })
        XCTAssertFalse(args.contains { $0.hasPrefix("-mfb=") })
        XCTAssertFalse(args.contains { $0.hasPrefix("-ms=") })
    }

    func testUpdateModeMapping() {
        var options = AdvancedCompressionOptions()
        options.updateMode = .addAndReplace
        XCTAssertFalse(AdvancedCompressionValidator.arguments(for: options, format: .sevenZip).contains { $0.hasPrefix("-up") })
        options.updateMode = .addOnly
        XCTAssertTrue(AdvancedCompressionValidator.arguments(for: options, format: .sevenZip).contains("-up1"))
        options.updateMode = .fresh
        XCTAssertTrue(AdvancedCompressionValidator.arguments(for: options, format: .sevenZip).contains("-up0"))
    }

    func testPathModeMapping() {
        var options = AdvancedCompressionOptions()
        options.pathMode = .relative
        XCTAssertTrue(AdvancedCompressionValidator.arguments(for: options, format: .sevenZip).contains("-spr0"))
        options.pathMode = .full
        XCTAssertTrue(AdvancedCompressionValidator.arguments(for: options, format: .sevenZip).contains("-spr1"))
    }

    func testSizeValidation() {
        XCTAssertTrue(AdvancedCompressionValidator.isValidSize("32m"))
        XCTAssertTrue(AdvancedCompressionValidator.isValidSize("1g"))
        XCTAssertTrue(AdvancedCompressionValidator.isValidSize("512k"))
        XCTAssertTrue(AdvancedCompressionValidator.isValidSize("1024"))
        XCTAssertFalse(AdvancedCompressionValidator.isValidSize(""))
        XCTAssertFalse(AdvancedCompressionValidator.isValidSize("abc"))
        XCTAssertFalse(AdvancedCompressionValidator.isValidSize("32x"))
    }

    func testInvalidValuesReported() {
        var options = AdvancedCompressionOptions()
        options.dictionarySize = "nope"
        options.wordSize = "999"
        options.threadCount = 0
        let problems = AdvancedCompressionValidator.validate(options, format: .sevenZip)
        XCTAssertTrue(problems.contains(.invalidSize(field: "Dictionary size", value: "nope")))
        XCTAssertTrue(problems.contains(.invalidWordSize("999")))
        XCTAssertTrue(problems.contains(.invalidThreadCount(0)))
    }

    func testZipRejectsSevenZipOnlyFields() {
        var options = AdvancedCompressionOptions()
        options.dictionarySize = "32m"
        let problems = AdvancedCompressionValidator.validate(options, format: .zip)
        XCTAssertTrue(problems.contains(.unsupportedForZip(field: "Dictionary size")))
    }

    func testSolidOffIsAccepted() {
        var options = AdvancedCompressionOptions()
        options.solidBlockSize = "off"
        XCTAssertTrue(AdvancedCompressionValidator.validate(options, format: .sevenZip).isEmpty)
    }
}
