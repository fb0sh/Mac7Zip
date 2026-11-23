import XCTest
@testable import Mac7Zip

final class FileOperationsServiceTests: XCTestCase {
    private var tempDir: URL!
    private let service = FileOperationsService()

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipOpsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
    }

    func testCreateFolder() async throws {
        let url = try await service.createFolder(named: "NewFolder", in: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "NewFolder")
    }

    func testCreateFolderDuplicateThrowsAlreadyExists() async throws {
        _ = try await service.createFolder(named: "Dup", in: tempDir)
        do {
            _ = try await service.createFolder(named: "Dup", in: tempDir)
            XCTFail("Expected alreadyExists")
        } catch let error as FileError {
            XCTAssertEqual(error, .alreadyExists("Dup"))
        }
    }

    func testCreateFolderInvalidName() async {
        do {
            _ = try await service.createFolder(named: "  ", in: tempDir)
            XCTFail("Expected invalidName")
        } catch let error as FileError {
            XCTAssertEqual(error, .invalidName("  "))
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func testRenameFile() async throws {
        let original = tempDir.appendingPathComponent("a.txt")
        try "x".write(to: original, atomically: true, encoding: .utf8)
        let renamed = try await service.rename(original, to: "b.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }

    func testRenameToExistingThrows() async throws {
        let a = tempDir.appendingPathComponent("a.txt")
        let b = tempDir.appendingPathComponent("b.txt")
        try "x".write(to: a, atomically: true, encoding: .utf8)
        try "y".write(to: b, atomically: true, encoding: .utf8)
        do {
            _ = try await service.rename(a, to: "b.txt")
            XCTFail("Expected alreadyExists")
        } catch let error as FileError {
            XCTAssertEqual(error, .alreadyExists("b.txt"))
        }
    }

    func testMoveToTrashMissingThrowsNotFound() async {
        let missing = tempDir.appendingPathComponent("nope.txt")
        do {
            try await service.moveToTrash(missing)
            XCTFail("Expected notFound")
        } catch let error as FileError {
            XCTAssertEqual(error, .notFound("nope.txt"))
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }
}
