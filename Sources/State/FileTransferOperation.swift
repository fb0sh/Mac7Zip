import Foundation

/// A `TaskOperation` that performs a file transfer on the task queue, reporting
/// real per-item progress and honouring cancellation between items.
struct FileTransferOperation: TaskOperation {
    let kind: TaskKind
    let title: String
    let request: FileTransferRequest
    private let service: FileTransferService
    private let onFinish: (@Sendable ([FileTransferOutcome]) -> Void)?

    init(
        request: FileTransferRequest,
        service: FileTransferService = FileTransferService(),
        onFinish: (@Sendable ([FileTransferOutcome]) -> Void)? = nil
    ) {
        self.request = request
        self.service = service
        self.onFinish = onFinish
        switch request.kind {
        case .copy: self.kind = .copy
        case .move: self.kind = .move
        case .duplicate: self.kind = .copy
        }
        let count = request.sources.count
        let verb = request.kind == .move ? "Moving" : request.kind == .duplicate ? "Duplicating" : "Copying"
        self.title = "\(verb) \(count) item\(count == 1 ? "" : "s")"
    }

    func run(report: @Sendable (Double?, TaskMetrics) -> Void) async throws {
        let total = request.sources.count
        report(nil, TaskMetrics(filesDone: 0, filesTotal: total, currentItem: request.sources.first?.lastPathComponent))

        var outcomes: [FileTransferOutcome] = []
        for (index, source) in request.sources.enumerated() {
            try Task.checkCancellation()

            let itemRequest = FileTransferRequest(
                kind: request.kind,
                sources: [source],
                destinationDirectory: request.destinationDirectory,
                conflictPolicy: request.conflictPolicy,
                preserveSymlinks: request.preserveSymlinks
            )
            outcomes.append(contentsOf: try await service.perform(itemRequest))

            let fraction = Double(index + 1) / Double(max(total, 1))
            report(fraction, TaskMetrics(
                filesDone: index + 1,
                filesTotal: total,
                currentItem: source.lastPathComponent
            ))
        }

        onFinish?(outcomes)

        let failures = outcomes.compactMap { outcome -> String? in
            if case .failed(let message) = outcome.status { return message }
            return nil
        }
        if let first = failures.first {
            throw FileError.operationFailed(first)
        }
    }
}
