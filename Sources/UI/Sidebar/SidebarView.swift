import SwiftUI

struct SidebarView: View {
    @ObservedObject var favourites: FavouritesStore
    var onOpen: (URL) -> Void

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
        .listStyle(.sidebar)
        .navigationTitle("Mac7Zip")
        .frame(minWidth: 180)
    }
}
