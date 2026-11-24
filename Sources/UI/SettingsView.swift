import SwiftUI

/// Settings window (TKT-M5-02). Changes persist via `SettingsStore` and affect
/// subsequent operations immediately.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @StateObject private var iconRegistrar = FileIconRegistrar()

    var body: some View {
        TabView {
            archiveTab
                .tabItem { Label("Archives", systemImage: "archivebox") }
            limitsTab
                .tabItem { Label("Limits", systemImage: "gauge") }
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            fileIconsTab
                .tabItem { Label("File Icons", systemImage: "doc.badge.gearshape") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
        .padding()
    }

    private var archiveTab: some View {
        Form {
            Section("Double-click an archive") {
                Picker("Action", selection: $store.settings.activation) {
                    ForEach(ArchiveActivation.allCases, id: \.self) { activation in
                        Text(activation.displayName).tag(activation)
                    }
                }
                Text("“Open” browses the archive; “Extract” writes a sibling <name>/ folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Defaults") {
                Toggle("Extract into a subfolder by default", isOn: $store.settings.extractSubfolderByDefault)
                Picker("Default archive format", selection: $store.settings.defaultFormatRaw) {
                    Text("7z").tag("7z")
                    Text("ZIP").tag("zip")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var limitsTab: some View {
        Form {
            Section("Extraction safety limits") {
                TextField(
                    "Maximum total size (bytes)",
                    value: $store.settings.maxTotalBytes,
                    format: .number
                )
                TextField(
                    "Maximum expansion ratio",
                    value: $store.settings.maxExpansionRatio,
                    format: .number
                )
                TextField(
                    "Maximum entry count",
                    value: $store.settings.maxEntryCount,
                    format: .number
                )
                ForEach(store.settings.validationErrors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Reset to Defaults") { store.reset() }
            }
        }
        .formStyle(.grouped)
    }

    private var fileIconsTab: some View {
        Form {
            Section("Finder file icons") {
                Text("Register per-type archive icons so Finder shows the matching icon for .7z/.zip/.rar and more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Register file icons") { _ = iconRegistrar.register() }
                    Button("Restore system defaults") { _ = iconRegistrar.restoreDefaults() }
                }
                LabeledContent("Status") {
                    Text(iconRegistrar.isRegistered ? "Registered" : "Not registered")
                        .foregroundStyle(iconRegistrar.isRegistered ? .green : .secondary)
                }
                Text("macOS may ask you to confirm changing the default app for these types. Ad-hoc signed builds may be ignored by LaunchServices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Notify me when a task finishes", isOn: $store.settings.sendCompletionNotifications)
                Toggle("Restore the last folder on launch", isOn: $store.settings.restoreLastLocation)
            }
        }
        .formStyle(.grouped)
    }
}
