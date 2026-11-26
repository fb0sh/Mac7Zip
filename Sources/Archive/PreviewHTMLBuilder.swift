import Foundation

/// Builds the HTML shown by the Quick Look preview extension. Pure & testable.
///
/// Entries are rendered as a collapsible tree: folders use native `<details>`, so
/// the reader can expand inner folders without any scripting, and nothing is
/// clickable beyond that (Quick Look stays a read-only glance).
enum PreviewHTMLBuilder {
    struct Item {
        let path: String
        let sizeText: String
        let dateText: String
        let isDirectory: Bool
        /// `data:image/png;base64,…` for the entry's real icon. When nil the row
        /// falls back to a plain glyph.
        let iconDataURL: String?
        init(path: String, sizeText: String, dateText: String, isDirectory: Bool, iconDataURL: String? = nil) {
            self.path = path; self.sizeText = sizeText; self.dateText = dateText
            self.isDirectory = isDirectory; self.iconDataURL = iconDataURL
        }
    }

    struct Node {
        let name: String
        let isDirectory: Bool
        let sizeText: String
        let dateText: String
        let iconDataURL: String?
        let children: [Node]
    }

    static func html(title: String, items: [Item], summary: String) -> String {
        let nodes = tree(from: items)
        var body = ""
        render(nodes, depth: 0, into: &body)
        if items.isEmpty {
            body = "<div class=\"empty\">无法读取内容</div>"
        }
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>
        body{font:13px -apple-system,Helvetica,sans-serif;color:#1d1d1f;margin:0;padding:14px;background:#fff}
        h2{font:600 14px -apple-system;margin:0 0 2px}
        .sum{color:#8a8a8e;font-size:12px;margin-bottom:10px}
        .row{display:grid;grid-template-columns:1fr 100px 78px;gap:10px;align-items:center;
             padding:4px 6px;border-bottom:1px solid #f2f2f7;font-size:12px}
        summary.row{list-style:none;cursor:default}
        summary.row::-webkit-details-marker{display:none}
        .n{word-break:break-all}
        .d{color:#6e6e73;white-space:nowrap}
        .s{color:#6e6e73;text-align:right;white-space:nowrap}
        .tw{display:inline-block;width:11px;color:#8a8a8e;font-size:9px;vertical-align:1px}
        details[open]>summary .tw::before{content:"▼"}
        .tw::before{content:"▶"}
        .leaf .tw::before{content:""}
        img.i{width:16px;height:16px;vertical-align:-3px;margin-right:5px}
        .kids{margin-left:15px}
        .empty{color:#8a8a8e;text-align:center;padding:20px}
        </style></head><body>
        <h2>\(escape(title))</h2><div class="sum">\(escape(summary))</div>
        \(body)
        </body></html>
        """
    }

    // MARK: - Tree building

    /// Groups flat entry paths into a tree. Implicit parents (paths that appear
    /// only as a prefix of deeper entries) become folders with no size/date.
    static func tree(from items: [Item]) -> [Node] {
        let root = MutableNode(name: "")
        for item in items {
            let components = item.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let lastIndex = components.indices.last else { continue }

            var current = root
            for (index, component) in components.enumerated() {
                let child = current.children[component] ?? MutableNode(name: component)
                current.children[component] = child
                if index == lastIndex {
                    child.isDirectory = item.isDirectory
                    child.sizeText = item.sizeText
                    child.dateText = item.dateText
                    child.iconDataURL = item.iconDataURL
                } else {
                    child.isDirectory = true
                }
                current = child
            }
        }
        return sortedChildren(of: root)
    }

    private final class MutableNode {
        let name: String
        var isDirectory = false
        var sizeText = "--"
        var dateText = ""
        var iconDataURL: String?
        var children: [String: MutableNode] = [:]

        init(name: String) { self.name = name }
    }

    private static func sortedChildren(of node: MutableNode) -> [Node] {
        node.children.values
            .sorted { left, right in
                if left.isDirectory != right.isDirectory { return left.isDirectory }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
            .map { child in
                Node(
                    name: child.name,
                    isDirectory: child.isDirectory,
                    sizeText: child.sizeText,
                    dateText: child.dateText,
                    iconDataURL: child.iconDataURL,
                    children: sortedChildren(of: child)
                )
            }
    }

    // MARK: - Rendering

    /// Only the outermost level starts expanded; deeper folders stay collapsed so
    /// a large archive does not open as thousands of rows.
    private static func render(_ nodes: [Node], depth: Int, into out: inout String) {
        for node in nodes {
            let icon: String
            if let dataURL = node.iconDataURL {
                icon = "<img class=\"i\" src=\"\(dataURL)\" alt=\"\">"
            } else {
                icon = ""
            }
            let cells = """
            <span class="d">\(escape(node.dateText))</span><span class="s">\(escape(node.sizeText))</span>
            """

            if node.isDirectory, !node.children.isEmpty {
                out += "<details\(depth == 0 ? " open" : "")>"
                out += "<summary class=\"row\"><span class=\"n\"><span class=\"tw\"></span>\(icon)\(escape(node.name))/</span>\(cells)</summary>"
                out += "<div class=\"kids\">"
                render(node.children, depth: depth + 1, into: &out)
                out += "</div></details>"
            } else {
                let suffix = node.isDirectory ? "/" : ""
                out += "<div class=\"row leaf\"><span class=\"n\"><span class=\"tw\"></span>\(icon)\(escape(node.name))\(suffix)</span>\(cells)</div>"
            }
        }
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
