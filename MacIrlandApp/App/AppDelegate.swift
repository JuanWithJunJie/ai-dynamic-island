import AppKit
import MacIrlandKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStateStore()

    private var panelCoordinator: PanelCoordinator?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelCoordinator = PanelCoordinator(store: store)
        let statusBarController = StatusBarController {
            panelCoordinator.togglePanel()
        }

        self.panelCoordinator = panelCoordinator
        self.statusBarController = statusBarController
        NSApp.setActivationPolicy(.accessory)
    }
}
