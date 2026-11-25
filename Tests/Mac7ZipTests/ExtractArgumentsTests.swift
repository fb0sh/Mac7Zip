import XCTest
@testable import Mac7Zip

final class ExtractArgumentsTests: XCTestCase {
    private let archive = URL(fileURLWithPath: "/tmp/a.zip")
    private let out = URL(fileURLWithPath: "/tmp/out")

    func testArchiveComesBeforeEntryFilters() {
        let args = SevenZipEngine.extractArguments(
            archive: archive, entries: ["docs/a.txt", "b.txt"],
            overwriteMode: .overwrite, passwordArguments: [], codePage: nil, outputDirectory: out
        )
        let archiveIndex = try! XCTUnwrap(args.firstIndex(of: "/tmp/a.zip"))
        let firstEntry = try! XCTUnwrap(args.firstIndex(of: "docs/a.txt"))
        XCTAssertLessThan(archiveIndex, firstEntry, "Entry filters must come AFTER the archive path")
        XCTAssertEqual(args.last, "-o/tmp/out")
        XCTAssertEqual(args.first, "x")
    }

    func testCodePageInsertedBeforeArchive() {
        let args = SevenZipEngine.extractArguments(
            archive: archive, entries: nil, overwriteMode: .ask,
            passwordArguments: ["-ppw"], codePage: 936, outputDirectory: out
        )
        let mcp = try! XCTUnwrap(args.firstIndex(of: "-mcp=936"))
        let archiveIndex = try! XCTUnwrap(args.firstIndex(of: "/tmp/a.zip"))
        XCTAssertLessThan(mcp, archiveIndex)
        XCTAssertTrue(args.contains("-ppw"))
    }

    func testNoEntriesStillValid() {
        let args = SevenZipEngine.extractArguments(
            archive: archive, entries: [], overwriteMode: .skip,
            passwordArguments: [], codePage: nil, outputDirectory: out
        )
        XCTAssertEqual(args.suffix(2), ["/tmp/a.zip", "-o/tmp/out"])
    }

    /// 7-Zip only accepts `-ao{a|s|t|u}`; emitting `-aoo` makes 7zz fail with
    /// "Incorrect switch postfix".
    func testOverwriteModeSwitchValuesAreAcceptedBy7Zip() {
        let accepted = Set(["a", "s", "t", "u"])
        for mode in [OverwriteMode.ask, .overwrite, .skip, .rename] {
            XCTAssertTrue(
                accepted.contains(mode.switchValue),
                "-ao\(mode.switchValue) is not a valid 7-Zip overwrite postfix"
            )
        }
    }
}
