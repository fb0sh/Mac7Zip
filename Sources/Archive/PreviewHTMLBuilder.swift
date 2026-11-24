import Foundation

/// Builds the HTML shown by the Quick Look preview extension. Pure & testable.
enum PreviewHTMLBuilder {
    struct Item {
        let path: String
        let sizeText: String
        let dateText: String
        let isDirectory: Bool
        init(path: String, sizeText: String, dateText: String, isDirectory: Bool) {
            self.path = path; self.sizeText = sizeText; self.dateText = dateText; self.isDirectory = isDirectory
        }
    }

    static func html(title: String, items: [Item], summary: String) -> String {
        var rows = ""
        for item in items {
            let icon = item.isDirectory ? "📁" : "📄"
            let name = escape(item.path)
            rows += "<tr><td class=\"n\">\(icon) \(name)</td><td class=\"d\">\(escape(item.dateText))</td><td class=\"s\">\(escape(item.sizeText))</td></tr>"
        }
        if items.isEmpty {
            rows = "<tr><td colspan=\"3\" class=\"empty\">无法读取内容</td></tr>"
        }
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>
        body{font:13px -apple-system,Helvetica,sans-serif;color:#1d1d1f;margin:0;padding:14px;background:#fff}
        h2{font:600 14px -apple-system;margin:0 0 2px}
        .sum{color:#8a8a8e;font-size:12px;margin-bottom:10px}
        table{border-collapse:collapse;width:100%}
        th{text-align:left;font-weight:600;color:#6e6e73;font-size:12px;border-bottom:1px solid #e5e5ea;padding:6px 8px}
        td{padding:5px 8px;border-bottom:1px solid #f2f2f7;font-size:12px}
        td.d{color:#6e6e73;white-space:nowrap}td.s{text-align:right;color:#6e6e73;white-space:nowrap}
        td.n{word-break:break-all}tr:nth-child(even) td{background:#fafafc}
        .empty{color:#8a8a8e;text-align:center;padding:20px}
        </style></head><body>
        <h2>\(escape(title))</h2><div class="sum">\(escape(summary))</div>
        <table><thead><tr><th>名称</th><th>修改时间</th><th>大小</th></tr></thead><tbody>\(rows)</tbody></table>
        </body></html>
        """
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
