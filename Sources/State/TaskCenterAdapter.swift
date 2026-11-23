import Combine
import Foundation

/// `@MainActor` bridge between the `TaskCenter` actor and SwiftUI. Keeps the
/// actor free of UI dependencies while giving views a synchronous snapshot.
@MainActor
final class TaskCenterAdapter: ObservableObject {
    @Published private(set) var records: [TaskRecord] = []

    private let center: TaskCenter
    private var observerID: UUID?

    init(center: TaskCenter = TaskCenter()) {
        self.center = center
    }

    /// Subscribes to task updates. Call once from the view's `.task`.
    func start() async {
        guard observerID == nil else { return }
        observerID = await center.addObserver { [weak self] snapshot in
            Task { @MainActor in
                self?.records = snapshot
            }
        }
        records = await center.allRecords
    }

    func stop() async {
        if let observerID {
            await center.removeObserver(observerID)
            self.observerID = nil
        }
    }

    @discardableResult
    func submit(_ operation: TaskOperation) async -> UUID {
        await center.submit(operation)
    }

    func cancel(_ id: UUID) async {
        await center.cancel(id)
    }

    // MARK: - Derived view state

    var activeRecords: [TaskRecord] {
        records.filter { !$0.state.isTerminal }
    }

    var finishedRecords: [TaskRecord] {
        records.filter { $0.state.isTerminal }.reversed()
    }

    var runningRecord: TaskRecord? {
        records.first { $0.state == .running || $0.state == .cancelling }
    }

    var hasActiveTasks: Bool { !activeRecords.isEmpty }
}
