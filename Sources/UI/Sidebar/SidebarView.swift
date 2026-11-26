import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @ObservedObject var favourites: FavouritesStore
    var onOpen: (URL) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        List {
            Section("Favourites") {
                ForEach(favourites.favourites) { favourite in
                    Button {
                        onOpen(favourite.url)
                    } label: {
                        Label(favourite.name, systemImage: "folder")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove from Favourites") { favourites.remove(favourite) }
                    }
                }
            }

            Section("System") {
                ForEach(SidebarLocation.allCases) { location in
                    Button {
                        onOpen(location.url)
                    } label: {
                        Label(location.title, systemImage: location.systemImage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // Without this the sidebar was a dead zone: dragging a folder in from
        // Finder did nothing. Dropping adds it to Favourites.
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            addToFavourites(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mac7Zip")
        .frame(minWidth: 180)
    }

    /// Adds every dropped folder to Favourites. Files are ignored: a favourite is
    /// a location to navigate to.
    private func addToFavourites(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, Self.isDirectory(url) else { return }
                Task { @MainActor in
                    favourites.add(url: url)
                }
            }
        }
        return true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
