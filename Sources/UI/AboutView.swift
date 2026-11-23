import SwiftUI

/// About + Licenses screen (TKT-M5-05).
struct AboutView: View {
    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Mac7Zip").font(.title2).bold()
                    Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                }
            }

            Text("A native macOS archive manager powered by the 7-Zip engine.")
                .font(.callout)

            Divider()

            ScrollView {
                Text(LicensesText.value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 220)
        }
        .padding()
        .frame(width: 520, height: 420)
    }
}

/// Loads bundled third-party notices, with an embedded fallback so the About
/// screen is never empty even if a resource is missing.
enum LicensesText {
    static let value: String = {
        let bundle = Bundle.main
        for name in ["NOTICE", "7zz-LICENSE"] {
            if let url = bundle.url(forResource: name, withExtension: "md")
                ?? bundle.url(forResource: name, withExtension: "txt"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return """
        Mac7Zip bundles 7-Zip 26.06 (LGPL v2.1+ with the unRAR restriction).
        The RAR code may not be used to build a RAR-compatible archiver, so
        Mac7Zip cannot create RAR archives. 7-Zip © Igor Pavlov and contributors.
        """
    }()
}
