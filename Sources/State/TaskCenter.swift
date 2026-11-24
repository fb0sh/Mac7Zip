import Foundation

enum TaskKind: String, Sendable, Codable {
    case list
    case extract
    case create
    case test
    case copy
    case move
}

enum TaskState: String, Sendable, Codable {
    case queued
    case running
    case cancelling
    case succeeded
    case failed
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled: return true
        case .queued, .running, .cancelling: return false
        }
    }
}

/// Optional metrics reported by the engine; `nil` means "unknown", never a fake value.
struct TaskMetrics: Sendable, Equatable {
    var processedBytes: Int64?
    var totalBytes: Int64?
    var filesDone: Int?
    var filesTotal: Int?
    var currentItem: String?
    var compressionRatio: Double?
}

struct TaskRecord: Identifiable, Sendable, Equatable {
    let id: UUID
    var kind: TaskKind
    var title: String
    var state: TaskState
    /// `nil` = indeterminate (never a fake percentage).
    var progress: Double?
    var startedAt: Date?
    var endedAt: Date?
    var errorDescription: String?
    var metrics: TaskMetrics = TaskMetrics()
}

/// One unit of background work executed by `TaskCenter`.
protocol TaskOperation: Sendable {
    var kind: TaskKind { get }
    var title: String { get }
    func run(report: @escaping @Sendable (Double?, TaskMetrics) -> Void) async throws
}

/// Centralized queue for archive operations. Deliberately independent of SwiftUI
/// so it can be unit-tested headless. Default concurrency is 1.
actor TaskCenter {
    private var records: [TaskRecord] = []
    private var queue: [(id: UUID, operation: TaskOperation)] = []
    private var running: UUID?
    private var runningTask: Task<Void, Never>?
    private var cancellationRequested: Set<UUID> = []
    private let maxConcurrency: Int
    private let historyLimit: Int
    private var observers: [UUID: @Sendable ([TaskRecord]) -> Void] = [:]

    init(maxConcurrency: Int = 1, historyLimit: Int = 50) {
        self.maxConcurrency = maxConcurrency
        self.historyLimit = historyLimit
    }

    var allRecords: [TaskRecord] { records }

    func addObserver(_ observer: @escaping @Sendable ([TaskRecord]) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    @discardableResult
    func submit(_ operation: TaskOperation) -> UUID {
        let id = UUID()
        records.append(TaskRecord(id: id, kind: operation.kind, title: operation.title, state: .queued, progress: nil))
        queue.append((id, operation))
        notify()
        startNextIfPossible()
        return id
    }

    func cancel(_ id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        if records[index].state == .queued {
            queue.removeAll { $0.id == id }
            records[index].state = .cancelled
            records[index].endedAt = Date()
            notify()
            return
        }
        if records[index].state == .running {
            records[index].state = .cancelling
            cancellationRequested.insert(id)
            // Actually cancel the running Swift task so `Task.checkCancellation()`
            // inside the operation fires. Without this, cancel was a no-op.
            runningTask?.cancel()
            notify()
        }
    }

    private func startNextIfPossible() {
        guard running == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        running = next.id
        guard let index = records.firstIndex(where: { $0.id == next.id }) else { return }
        records[index].state = .running
        records[index].startedAt = Date()
        notify()

        let operation = next.operation
        let taskID = next.id

        runningTask = Task.detached { [weak self] in
            do {
                try await operation.run { progress, metrics in
                    Task { await self?.updateProgress(taskID, progress: progress, metrics: metrics) }
                }
                await self?.finish(taskID, state: .succeeded, error: nil)
            } catch is CancellationError {
                await self?.finish(taskID, state: .cancelled, error: nil)
            } catch {
                await self?.finish(taskID, state: .failed, error: String(describing: error))
            }
        }
    }

    private func updateProgress(_ id: UUID, progress: Double?, metrics: TaskMetrics) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].progress = progress
        records[index].metrics = metrics
        notify()
    }

    private func finish(_ id: UUID, state: TaskState, error: String?) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            let wasCancelling = records[index].state == .cancelling || cancellationRequested.contains(id)
            records[index].state = wasCancelling && state != .succeeded ? .cancelled : state
            records[index].errorDescription = error
            records[index].endedAt = Date()
        }
        cancellationRequested.remove(id)
        running = nil
        runningTask = nil
        trimHistory()
        notify()
        startNextIfPossible()
    }

    private func trimHistory() {
        let finished = records.filter { $0.state.isTerminal }
        if finished.count > historyLimit {
            let excess = finished.count - historyLimit
            var removed = 0
            records.removeAll { record in
                guard removed < excess, record.state.isTerminal else { return false }
                removed += 1
                return true
            }
        }
    }

    private func notify() {
        let snapshot = records
        for observer in observers.values {
            observer(snapshot)
        }
    }
}
