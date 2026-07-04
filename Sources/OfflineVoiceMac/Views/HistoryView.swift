import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("历史记录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("最近转写")
                        .font(.largeTitle.weight(.bold))
                }
                Spacer()
                Button("清空", role: .destructive) {
                    store.clearHistory()
                }
                .disabled(store.history.isEmpty)
            }

            if store.history.isEmpty {
                ContentUnavailableView("还没有历史记录", systemImage: "clock.arrow.circlepath", description: Text("完成一次录音或文件转写后会显示在这里。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.history) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.text)
                            .lineLimit(4)
                        HStack {
                            Text(Formatters.time.string(from: record.createdAt))
                            Text(Formatters.duration(record.duration))
                            Text(URL(fileURLWithPath: record.modelPath).lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("复制文本") {
                            store.copyText(record.text)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(28)
    }
}
