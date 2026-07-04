import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section("识别") {
                Picker("语言", selection: $store.language) {
                    Text("自动").tag("auto")
                    Text("中文").tag("zh")
                    Text("英文").tag("en")
                }
                Toggle("转写完成后自动复制", isOn: $store.autoCopy)
                Toggle("保留录音文件路径", isOn: $store.keepAudio)
            }

            Section("路径") {
                LabeledContent("当前模型") {
                    Text(store.activeModelName)
                }
                LabeledContent("whisper-cli") {
                    Text(store.whisperPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("模型") {
                    Text(store.modelPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
