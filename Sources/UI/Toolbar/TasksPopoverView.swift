import SwiftUI

/// Popover listing running/queued/finished tasks with progress and cancel.
struct TasksPopoverView: View {
    @ObservedObject var adapter: TaskCenterAdapter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if adapter.records.isEmpty {
                ContentUnavailableView("No Tasks", systemImage: "checklist")
                    .frame(width: 360, height: 200)
            } else {
                List {
                    if !adapter.activeRecords.isEmpty {
                        Section("Active") {
                            ForEach(adapter.activeRecords) { record in
                                TaskRow(record: record) {
                                    Task { await adapter.cancel(record.id) }
                                }
                            }
                        }
                    }
                    if !adapter.finishedRecords.isEmpty {
                        Section("Completed") {
                            ForEach(Array(adapter.finishedRecords.prefix(20))) { record in
                                TaskRow(record: record, onCancel: nil)
                            }
                        }
                    }
                }
                .frame(width: 380, height: 320)
            }
        }
    }
}

private struct TaskRow: View {
    let record: TaskRecord
    let onCancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(record.title).lineLimit(1)
                Spacer()
                if let onCancel, record.state == .running {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
            }
            if record.state == .running || record.state == .cancelling {
                if let progress = record.progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            if let metricsLine {
                Text(metricsLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = record.errorDescription {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    /// Only real values are shown; unknown metrics stay hidden (FR-TM-10).
    private var metricsLine: String? {
        var parts: [String] = []
        if let done = record.metrics.filesDone, let total = record.metrics.filesTotal {
            parts.append("\(done)/\(total) files")
        }
        if let processed = record.metrics.processedBytes {
            parts.append(FileSizeFormatter.string(fromByteCount: processed))
        }
        if let ratio = record.metrics.compressionRatio {
            parts.append(String(format: "%.0f%%", ratio * 100))
        }
        if let item = record.metrics.currentItem, !item.isEmpty {
            parts.append(item)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var iconName: String {
        switch record.state {
        case .queued: return "clock"
        case .running, .cancelling: return "arrow.triangle.2.circlepath"
        case .succeeded: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        case .cancelled: return "slash.circle"
        }
    }

    private var iconColor: Color {
        switch record.state {
        case .failed: return .red
        case .succeeded: return .green
        default: return .secondary
        }
    }
}
