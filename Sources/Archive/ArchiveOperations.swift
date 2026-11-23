import Foundation

/// Runs an extraction through `TaskCenter` so it is queued, cancellable and
/// observable. Bridges the engine to the task model.
struct ExtractOperation: TaskOperation {
    let kind: TaskKind = .extract
    let title: String
    let engine: ArchiveEngine
    let archive: URL
    let destination: URL
    let options: ExtractOptions

    init(engine: ArchiveEngine, archive: URL, destination: URL, options: ExtractOptions, title: String? = nil) {
        self.engine = engine
        self.archive = archive
        self.destination = destination
        self.options = options
        self.title = title ?? "Extract \(archive.lastPathComponent)"
    }

    func run(report: @Sendable (Double?, TaskMetrics) -> Void) async throws {
        // Extraction progress is not yet streamed from the engine; report
        // indeterminate rather than a fabricated percentage.
        report(nil, TaskMetrics(currentItem: archive.lastPathComponent))
        try Task.checkCancellation()
        try await engine.extract(archive: archive, to: destination, options: options)
        report(1.0, TaskMetrics(currentItem: archive.lastPathComponent))
    }
}

/// Runs an archive creation through `TaskCenter`.
struct CreateArchiveOperation: TaskOperation {
    let kind: TaskKind = .create
    let title: String
    let engine: ArchiveEngine
    let destination: URL
    let sources: [URL]
    let options: ArchiveOptions

    init(engine: ArchiveEngine, destination: URL, sources: [URL], options: ArchiveOptions, title: String? = nil) {
        self.engine = engine
        self.destination = destination
        self.sources = sources
        self.options = options
        self.title = title ?? "Create \(destination.lastPathComponent)"
    }

    func run(report: @Sendable (Double?, TaskMetrics) -> Void) async throws {
        report(nil, TaskMetrics(currentItem: destination.lastPathComponent))
        try Task.checkCancellation()
        try await engine.createArchive(at: destination, from: sources, options: options)
        report(1.0, TaskMetrics(currentItem: destination.lastPathComponent))
    }
}
