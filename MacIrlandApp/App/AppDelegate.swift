import AppKit
import MacIrlandKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let openPanelOnLaunchKey = "OpenPanelOnLaunch"

    let store = TaskStateStore(
        observationService: RealTerminalObservationService(),
        permissionService: AutomationPermissionService()
    )

    private(set) lazy var panelCoordinator = PanelCoordinator(store: store)
    private lazy var statusBarController = StatusBarController(store: store) {
        self.panelCoordinator.togglePanel()
    }
    private lazy var islandCoordinator = IslandCoordinator(store: store) {
        self.panelCoordinator.showPanelSelectingTopSession()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchMode = AppLaunchSupport.detectLaunchMode()

        if AppLaunchSupport.shouldWarnForUnsupportedLaunchMode(launchMode) {
            presentUnsupportedLaunchAlert()
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.regular)
        _ = statusBarController
        _ = islandCoordinator
        openPanelIfRequested()
    }

    private func openPanelIfRequested() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.openPanelOnLaunchKey) else {
            return
        }

        defaults.removeObject(forKey: Self.openPanelOnLaunchKey)

        DispatchQueue.main.async { [weak self] in
            self?.panelCoordinator.togglePanel()
        }
    }

    private func presentUnsupportedLaunchAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "请使用 dev app 启动"
        alert.informativeText = AppLaunchSupport.unsupportedLaunchMessage
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}
