import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 24) {
            header

            HStack(alignment: .top, spacing: 18) {
                recorderPanel
                transcriptPanel
            }
        }
        .padding(28)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.transcribeFile()
                } label: {
                    Label("转写文件", systemImage: "waveform.badge.magnifyingglass")
                }

                Button {
                    Task { await store.toggleRecording() }
                } label: {
                    Label(store.isRecording ? "停止" : "录音", systemImage: store.isRecording ? "stop.fill" : "mic.fill")
                }
                .keyboardShortcut(.space, modifiers: [.control])
                .disabled(store.isTranscribing)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("语音输入工作台")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("原生 macOS 离线转写")
                    .font(.largeTitle.weight(.bold))
            }
            Spacer()
            Label(modelLabel, systemImage: "cpu")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var recorderPanel: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(.pink.opacity(0.12))
                    .frame(width: 190, height: 190)
                    .scaleEffect(1 + store.recorder.level * 0.16)
                Button {
                    Task { await store.toggleRecording() }
                } label: {
                    Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 126, height: 126)
                        .background(store.isRecording ? Color.green : Color.pink, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(store.isTranscribing)
            }

            VStack(spacing: 6) {
                Text(store.status)
                    .font(.title3.weight(.semibold))
                Text("点击按钮或按 Ctrl + Space")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MetricBox(title: "时长", value: Formatters.duration(store.recorder.elapsed), symbol: "clock")
                MetricBox(title: "音量", value: "\(Int(store.recorder.level * 100))%", symbol: "speaker.wave.2")
                MetricBox(title: "语言", value: store.languageLabel, symbol: "character.cursor.ibeam")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 460)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("转写结果")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("当前文本")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Button {
                    store.copyCurrentText()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .disabled(store.currentText.isEmpty)
            }

            TextEditor(text: .constant(store.currentText))
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if store.currentText.isEmpty {
                        Text("录音结束后，真实 whisper.cpp 转写内容会显示在这里。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(20)
                    }
                }

            if !store.errorMessage.isEmpty {
                Label(store.errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Toggle("转写完成后自动复制", isOn: $store.autoCopy)
        }
        .frame(maxWidth: .infinity, minHeight: 460)
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var modelLabel: String { store.activeModelName }
}

private struct MetricBox: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.pink)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension AppStore {
    var languageLabel: String {
        switch language {
        case "zh": "中文"
        case "en": "英文"
        default: "自动"
        }
    }
}
