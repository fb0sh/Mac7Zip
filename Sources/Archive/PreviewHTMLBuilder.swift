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
        /// Finder-style kind ("ZIP document", "Folder", …). Shown in the Kind column.
        let kindText: String
        /// `data:image/png;base64,…` for the entry's real icon. When nil the row
        /// falls back to a plain glyph.
        let iconDataURL: String?
        init(
            path: String,
            sizeText: String,
            dateText: String,
            isDirectory: Bool,
            kindText: String = "",
            iconDataURL: String? = nil
        ) {
            self.path = path; self.sizeText = sizeText; self.dateText = dateText
            self.isDirectory = isDirectory; self.kindText = kindText; self.iconDataURL = iconDataURL
        }
    }

    struct Node {
        let name: String
        let isDirectory: Bool
        let sizeText: String
        let dateText: String
        let kindText: String
        let iconDataURL: String?
        let children: [Node]
    }

    static func html(title: String, items: [Item], summary: String) -> String {
        let icons = IconTable(items: items)
        let nodes = tree(from: items)
        var body = ""
        if items.isEmpty {
            body = "<div class=\"empty\">无法读取内容</div>"
        } else {
            body = header()
            render(nodes, depth: 0, icons: icons, into: &body)
        }
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>
        body{font:13px -apple-system,Helvetica,sans-serif;color:#1d1d1f;margin:0;padding:14px;background:#fff}
        h2{font:600 14px -apple-system;margin:0 0 2px}
        .sum{color:#8a8a8e;font-size:12px;margin-bottom:10px}
        .row{display:grid;grid-template-columns:1fr 82px 150px 128px;gap:10px;align-items:center;
             padding:5px 6px;border-bottom:1px solid #f2f2f7;font-size:12px}
        .hdr{color:#6e6e73;font-weight:600;border-bottom:1px solid #e5e5ea}
        summary.row{list-style:none;cursor:default}
        summary.row::-webkit-details-marker{display:none}
        .n{word-break:break-all}
        .k{color:#3a3a3c;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .d{color:#6e6e73;white-space:nowrap}
        .s{color:#6e6e73;text-align:right;white-space:nowrap}
        .hdr .s{text-align:right}
        .tw{display:inline-block;width:11px;color:#8a8a8e;font-size:9px;vertical-align:1px}
        details[open]>summary .tw::before{content:"▼"}
        .tw::before{content:"▶"}
        .leaf .tw::before{content:""}
        i.i{display:inline-block;width:16px;height:16px;margin-right:5px;vertical-align:-3px;
             background-size:16px 16px;background-repeat:no-repeat}
        .kids{margin-left:15px}
        .empty{color:#8a8a8e;text-align:center;padding:20px}
        \(icons.css)
        </style></head><body>
        <h2>\(escape(title))</h2><div class="sum">\(escape(summary))</div>
        \(body)
        </body></html>
        """
    }

    /// Column headings, matching Finder's list view order.
    private static func header() -> String {
        """
        <div class="row hdr"><span>名称</span><span class="s">大小</span><span>种类</span><span>修改时间</span></div>
        """
    }

    /// Distinct icon data URLs mapped to short CSS classes. An archive repeats a
    /// handful of types across thousands of entries, so inlining the base64 data
    /// URL per row would bloat the HTML by megabytes and stall Quick Look.
    struct IconTable {
        private let index: [String: Int]
        /// `.i0{background-image:url(data:…)}` rules, one per distinct icon.
        let css: String

        init(items: [Item]) {
            var order: [String] = []
            var index: [String: Int] = [:]
            for item in items {
                guard let dataURL = item.iconDataURL, index[dataURL] == nil else { continue }
                index[dataURL] = order.count
                order.append(dataURL)
            }
            self.index = index
            self.css = order.enumerated()
                .map { ".i\($0.offset){background-image:url(\($0.element))}" }
                .joined(separator: "\n")
        }

        /// Class name for an item's icon, or nil when it has none.
        func className(for dataURL: String?) -> String? {
            guard let dataURL, let position = index[dataURL] else { return nil }
            return "i\(position)"
        }
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
                    child.kindText = item.kindText
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
        var kindText = ""
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
                    kindText: child.kindText,
                    iconDataURL: child.iconDataURL,
                    children: sortedChildren(of: child)
                )
            }
    }

    // MARK: - Rendering

    /// Only the outermost level starts expanded; deeper folders stay collapsed so
    /// a large archive does not open as thousands of rows.
    private static func render(_ nodes: [Node], depth: Int, icons: IconTable, into out: inout String) {
        for node in nodes {
            // The data URL lives once in the stylesheet; rows only carry the class.
            let icon = icons.className(for: node.iconDataURL).map { "<i class=\"i \($0)\"></i>" } ?? ""
            // Finder's column order: Name, Size, Kind, Date Modified.
            let cells = """
            <span class="s">\(escape(node.sizeText))</span>\
            <span class="k">\(escape(node.kindText))</span>\
            <span class="d">\(escape(node.dateText))</span>
            """

            if node.isDirectory, !node.children.isEmpty {
                out += "<details\(depth == 0 ? " open" : "")>"
                out += "<summary class=\"row\"><span class=\"n\"><span class=\"tw\"></span>\(icon)\(escape(node.name))/</span>\(cells)</summary>"
                out += "<div class=\"kids\">"
                render(node.children, depth: depth + 1, icons: icons, into: &out)
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
