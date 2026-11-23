import Foundation

/// Path helpers shared by the file-system layer and the breadcrumb UI.
enum PathUtilities {
    struct Breadcrumb: Equatable, Sendable {
        let title: String
        let url: URL
    }

    static func isRoot(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path == "/" || url.standardizedFileURL.pathComponents.count <= 1
    }

    static func parent(of url: URL) -> URL? {
        isRoot(url) ? nil : url.standardizedFileURL.deletingLastPathComponent()
    }

    /// Builds the clickable hierarchy from the filesystem root to `url`.
    static func breadcrumbs(for url: URL) -> [Breadcrumb] {
        var components = url.standardizedFileURL.pathComponents
        var result: [Breadcrumb] = []
        var current = URL(fileURLWithPath: "/")

        if components.first == "/" {
            result.append(Breadcrumb(title: "/", url: current))
            components.removeFirst()
        }

        for component in components {
            current = current.appendingPathComponent(component)
            result.append(Breadcrumb(title: component, url: current))
        }
        return result
    }
}
