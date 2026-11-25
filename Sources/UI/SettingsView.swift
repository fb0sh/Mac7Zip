import SwiftUI

/// Settings window (TKT-M5-02). Changes persist via `SettingsStore` and affect
/// subsequent operations immediately.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @StateObject private var iconRegistrar = FileIconRegistrar()
    @State private var selectedDefaultExtensions: Set<String> = []
    @State private var finderStatus: FinderExtensionState = .unknown

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
        .frame(width: 520, height: 380)
        .task { finderStatus = await FinderExtensionChecker.check() }
        .padding()
    }

    private var finderStatusText: String {
        switch finderStatus {
        case .enabled: return "已启用"
        case .disabled: return "已安装但未启用"
        case .notInstalled: return "未注册"
        case .unknown: return "未知"
        }
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
                Picker("ZIP file-name encoding", selection: $store.settings.zipEncoding) {
                    ForEach(ZipFileNameEncoding.allCases, id: \.self) { encoding in
                        Text(encoding.displayName).tag(encoding)
                    }
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
                Text("Step 1: let the system learn Mac7Zip’s per-type icons. This changes NO default apps and shows NO dialogs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Register with system (no dialogs)") { iconRegistrar.register() }

                Text("Step 2 (optional): macOS only shows a type’s icon from its default opener. Pick just the formats you want Mac7Zip to open by default — each adds ONE confirmation dialog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], alignment: .leading) {
                        ForEach(ArchiveFileIconCatalog.extensions, id: \.self) { ext in
                            Toggle(ext, isOn: Binding(
                                get: { selectedDefaultExtensions.contains(ext) },
                                set: { isOn in
                                    if isOn { selectedDefaultExtensions.insert(ext) }
                                    else { selectedDefaultExtensions.remove(ext) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 110)

                HStack {
                    Button("Set selected as default") {
                        _ = iconRegistrar.setDefault(forExtensions: Array(selectedDefaultExtensions))
                        selectedDefaultExtensions.removeAll()
                    }
                    .disabled(selectedDefaultExtensions.isEmpty)
                    Button("Restore system defaults") { _ = iconRegistrar.restoreDefaults() }
                }
                LabeledContent("Status") {
                    Text(iconRegistrar.isRegistered ? "Registered" : "Not registered")
                        .foregroundStyle(iconRegistrar.isRegistered ? .green : .secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section("Finder 右键菜单") {
                LabeledContent("状态") {
                    Text(finderStatusText)
                        .foregroundStyle(finderStatus == .enabled ? .green : .secondary)
                }
                HStack {
                    Button("启用/注册扩展") {
                        FinderExtensionChecker.enable()
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            finderStatus = await FinderExtensionChecker.check()
                        }
                    }
                    Button("重新检查") {
                        Task { finderStatus = await FinderExtensionChecker.check() }
                    }
                    Button("启用预览扩展") {
                        FinderExtensionChecker.enablePreview()
                    }
                }
            }
            Section {
                Toggle("Notify me when a task finishes", isOn: $store.settings.sendCompletionNotifications)
                Toggle("Restore the last folder on launch", isOn: $store.settings.restoreLastLocation)
            }
        }
        .formStyle(.grouped)
    }
}
