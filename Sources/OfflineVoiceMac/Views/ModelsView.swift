import SwiftUI

struct ModelsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ModelChoiceCard(
                        title: "内置标准模型",
                        badge: "默认",
                        subtitle: "ggml-base.bin",
                        detail: "已内置到应用包内，速度和准确率均衡，适合日常语音输入。",
                        size: "约 141 MB",
                        symbol: "checkmark.seal.fill",
                        isSelected: store.isUsingBaseModel,
                        isAvailable: store.baseModelAvailable,
                        actionTitle: store.isUsingBaseModel ? "使用中" : "使用标准模型",
                        action: store.useBuiltInBaseModel
                    )

                    ModelChoiceCard(
                        title: "高精度大模型",
                        badge: "可选",
                        subtitle: "ggml-large-v3.bin",
                        detail: "准确率更高，适合长音频或更复杂口音；加载和转写都会更慢。",
                        size: "约 2.9 GB",
                        symbol: "sparkles",
                        isSelected: store.isUsingLargeModel,
                        isAvailable: store.largeModelAvailable,
                        isDownloading: store.isDownloadingLargeModel,
                        downloadProgress: store.largeModelDownloadProgress,
                        actionTitle: store.largeModelAvailable
                            ? (store.isUsingLargeModel ? "使用中" : "切换到大模型")
                            : "下载大模型",
                        action: {
                            if store.largeModelAvailable {
                                store.useLargeModel()
                            } else {
                                store.downloadLargeModel()
                            }
                        }
                    )
                }

                if !store.errorMessage.isEmpty {
                    Label(store.errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("高级设置", systemImage: "wrench.and.screwdriver")
                        .font(.headline)

                    AdvancedPathRow(title: "whisper-cli", path: store.whisperPath) {
                        store.chooseWhisperCLI()
                    }

                    AdvancedPathRow(title: "当前模型路径", path: store.modelPath.isEmpty ? "未选择" : store.modelPath) {
                        store.chooseModel()
                    }

                    Text("一般不需要改这里。只有当你要测试其他 whisper.cpp 模型，或 Homebrew 路径不同时才需要手动选择。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本地模型")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("选择转写精度")
                .font(.largeTitle.weight(.bold))
            Text("标准模型已内置，打开即可用；大模型只是可选项，不会自动加载。")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ModelChoiceCard: View {
    let title: String
    let badge: String
    let subtitle: String
    let detail: String
    let size: String
    let symbol: String
    let isSelected: Bool
    let isAvailable: Bool
    var isDownloading = false
    var downloadProgress = 0.0
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .pink)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? Color.pink : Color.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.title3.weight(.semibold))
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Label("当前", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Text(detail)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            if isDownloading {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: downloadProgress)
                    Text("正在下载 \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label(size, systemImage: "externaldrive")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(actionTitle, action: action)
                    .disabled(isSelected || isDownloading)
            }

            if !isAvailable {
                Text("未找到本机模型，可下载后切换。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(isSelected ? Color.pink.opacity(0.08) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.pink.opacity(0.55) : Color.clear, lineWidth: 1)
        }
    }
}

private struct AdvancedPathRow: View {
    let title: String
    let path: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(path)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("选择", action: action)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}
