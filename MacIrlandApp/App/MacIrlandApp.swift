import AppKit
import SwiftUI
import MacIrlandKit

@main
struct MacIrlandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: appDelegate.store)
        }
    }
}
