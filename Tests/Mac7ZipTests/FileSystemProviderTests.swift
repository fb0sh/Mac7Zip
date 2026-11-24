import XCTest
@testable import Mac7Zip

final class FileSystemProviderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try "hello".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("sub", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
    }

    func testRealProviderListsDirectory() async throws {
        let provider = RealFileSystemProvider()
        let items = try await provider.list(.real(tempDir))
        let names = Set(items.map(\.name))
        XCTAssertTrue(names.contains("a.txt"))
        XCTAssertTrue(names.contains("sub"))
        XCTAssertEqual(items.count, 2)
    }

    func testRealProviderRejectsArchiveLocation() async {
        let provider = RealFileSystemProvider()
        do {
            _ = try await provider.list(.archive(archiveURL: URL(fileURLWithPath: "/tmp/a.zip"), internalPath: ""))
            XCTFail("Expected unsupportedLocation")
        } catch let error as FileSystemProviderError {
            XCTAssertEqual(error, .unsupportedLocation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRealProviderCapabilitiesIncludeMutation() {
        let provider = RealFileSystemProvider()
        XCTAssertEqual(provider.kind, .real)
        XCTAssertTrue(provider.capabilities.contains(.list))
        XCTAssertTrue(provider.capabilities.contains(.writeFile))
        XCTAssertTrue(provider.capabilities.contains(.rename))
        XCTAssertTrue(provider.capabilities.contains(.delete))
        XCTAssertTrue(provider.capabilities.contains(.createDirectory))
    }
}
