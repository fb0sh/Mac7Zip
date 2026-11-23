import Foundation

/// Explicit browse load state driving the UI (empty / loading / loaded / failed).
enum LoadState: Equatable {
    case empty
    case loading
    case loaded
    case failed(String)
}
