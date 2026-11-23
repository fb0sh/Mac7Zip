import Combine
import Foundation

/// A user bookmark shown in the sidebar.
struct FavouriteLocation: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let path: String

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }

    init(name: String, url: URL) {
        self.name = name
        self.path = url.standardizedFileURL.path
    }
}

/// User favourites, persisted to `UserDefaults` as JSON (TKT-M4-04).
@MainActor
final class FavouritesStore: ObservableObject {
    @Published private(set) var favourites: [FavouriteLocation]

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "Mac7Zip.favourites.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FavouriteLocation].self, from: data) {
            self.favourites = decoded
        } else {
            self.favourites = FavouritesStore.defaultFavourites()
            persist()
        }
    }

    static func defaultFavourites() -> [FavouriteLocation] {
        [
            FavouriteLocation(name: "Home", url: FileLocations.home),
            FavouriteLocation(name: "Desktop", url: FileLocations.desktop),
            FavouriteLocation(name: "Documents", url: FileLocations.documents),
            FavouriteLocation(name: "Downloads", url: FileLocations.downloads),
            FavouriteLocation(name: "Applications", url: FileLocations.applications),
        ]
    }

    /// Adds a folder; ignores duplicates (case-insensitive path match).
    @discardableResult
    func add(url: URL, name: String? = nil) -> Bool {
        let location = FavouriteLocation(name: name ?? url.lastPathComponent, url: url)
        guard !favourites.contains(where: { $0.path == location.path }) else { return false }
        favourites.append(location)
        persist()
        return true
    }

    func remove(_ location: FavouriteLocation) {
        favourites.removeAll { $0.path == location.path }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        favourites.remove(atOffsets: offsets)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        favourites.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func isFavourite(_ url: URL) -> Bool {
        favourites.contains { $0.path == url.standardizedFileURL.path }
    }

    /// Restores the built-in set (user additions are discarded).
    func resetToDefaults() {
        favourites = FavouritesStore.defaultFavourites()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(favourites) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Dual-pane layout state (TKT-M4-05). Pane 0 is primary, pane 1 secondary.
@MainActor
final class DualPaneController: ObservableObject {
    @Published private(set) var isDualPane: Bool
    @Published private(set) var activePane: Int

    init(isDualPane: Bool = false, activePane: Int = 0) {
        self.isDualPane = isDualPane
        self.activePane = activePane
    }

    func toggle() {
        isDualPane.toggle()
        if !isDualPane { activePane = 0 }
    }

    /// Activates a pane; ignored when dual-pane is off or the index is out of range.
    func setActive(_ index: Int) {
        guard isDualPane, index == 0 || index == 1 else { return }
        activePane = index
    }
}
