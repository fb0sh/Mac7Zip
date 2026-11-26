import XCTest
@testable import Mac7Zip

/// The Finder Services menu only appears when three things agree: the Info.plist
/// declares each entry with a matching `NSMessage` and `NSPortName`, the app
/// registers itself as the services provider, and the delegate exposes an
/// `@objc` method with that exact selector signature.
final class FinderServicesTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    private var yml: String {
        (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
    }

    func testEveryServiceDeclaresAMessageAndPortName() {
        let messages = [
            "openArchiveService", "extractHereService", "extractToFolderService",
            "testArchiveService", "addToArchiveService",
        ]
        for message in messages {
            XCTAssertTrue(yml.contains("NSMessage: \(message)"), "Missing NSMessage \(message)")
        }
        // Without NSPortName the system cannot route the menu item to us.
        let portNames = yml.components(separatedBy: "NSPortName: Mac7Zip").count - 1
        XCTAssertEqual(portNames, messages.count, "Every service needs NSPortName: Mac7Zip")
    }

    func testServicesProviderIsRegistered() {
        let source = (try? String(
            contentsOf: repoRoot.appendingPathComponent("Sources/App/FileOpenCoordinator.swift"),
            encoding: .utf8
        )) ?? ""
        XCTAssertTrue(source.contains("NSApp.servicesProvider = self"),
                      "AppKit only routes services once a provider is registered")
    }

    /// Each plist NSMessage must have a delegate method with the AppKit
    /// services signature, otherwise the menu item is shown but does nothing.
    func testEveryMessageHasADelegateMethod() {
        let source = (try? String(
            contentsOf: repoRoot.appendingPathComponent("Sources/App/FileOpenCoordinator.swift"),
            encoding: .utf8
        )) ?? ""
        for message in [
            "openArchiveService", "extractHereService", "extractToFolderService",
            "testArchiveService", "addToArchiveService",
        ] {
            XCTAssertTrue(
                source.contains("@objc func \(message)(_ pboard: NSPasteboard"),
                "Missing services method for \(message)"
            )
        }
    }
}
