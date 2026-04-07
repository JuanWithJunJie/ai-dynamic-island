import AppKit
import SwiftUI
import MacIrlandKit

@main
struct MacIrlandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("显示 / 隐藏面板") {
                appDelegate.panelCoordinator.togglePanel()
            }

            Divider()

            Button("打开设置") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("退出") {
                NSApp.terminate(nil)
            }
        } label: {
            MenuBarStatusLabel(
                summary: appDelegate.store.summary,
                topSession: appDelegate.store.topSession
            )
        }

        Settings {
            SettingsView(viewModel: appDelegate.store)
        }
    }
}
