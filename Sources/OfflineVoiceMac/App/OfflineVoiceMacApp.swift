import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct OfflineVoiceMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("离线语音", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandMenu("语音") {
                Button(store.isRecording ? "停止录音" : "开始录音") {
                    Task { await store.toggleRecording() }
                }
                .keyboardShortcut(.space, modifiers: [.control])

                Button("复制当前文本") {
                    store.copyCurrentText()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(store.currentText.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 560)
        }
    }
}
