import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var model: FileBrowserModel
    @EnvironmentObject private var tasks: TaskCenterAdapter

    var body: some View {
        HStack(spacing: 10) {
            Text(itemCountText)
            if !model.selection.isEmpty {
                Divider().frame(height: 12)
                Text(selectionText)
            }
            Spacer(minLength: 0)
            if let running = tasks.runningRecord {
                Text(running.title)
                    .lineLimit(1)
                if let progress = running.progress {
                    ProgressView(value: progress)
                        .frame(width: 140)
                    Text("\(Int(progress * 100))%")
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            } else if model.isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var itemCountText: String {
        "\(model.items.count) items"
    }

    private var selectionText: String {
        let count = model.selection.count
        let size = FileSizeFormatter.string(fromByteCount: model.selectedSize)
        return "\(count) selected — \(size)"
    }
}
