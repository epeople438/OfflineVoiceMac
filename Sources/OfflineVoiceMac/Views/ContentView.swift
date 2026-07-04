import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $store.selection)
        } detail: {
            switch store.selection ?? .record {
            case .record:
                RecordView()
            case .models:
                ModelsView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
    }
}
