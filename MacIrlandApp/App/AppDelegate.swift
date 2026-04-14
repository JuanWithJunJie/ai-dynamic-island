import AppKit
import MacIrlandKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStateStore(
        observationService: RealTerminalObservationService(),
        permissionService: AutomationPermissionService(),
        localStore: UserDefaultsLocalStore()
    )

    private lazy var statusBarController = StatusBarController(store: store) {
        // Dedicated panel has been removed - do nothing on menu bar click
    }
    private lazy var islandCoordinator = IslandCoordinator(store: store)
    private lazy var refreshCoordinator = RefreshCoordinator(store: store)
    private var hookSocketServer: HookSocketServer?

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
        refreshCoordinator.start()

        // Initialize hook socket server if hook is installed
        startHookSocketServerIfInstalled()
    }

    private func startHookSocketServerIfInstalled() {
        let installer = HookInstaller()
        guard installer.checkInstalled() else {
            return
        }

        if installer.isFullyInstalled() == false {
            do {
                try installer.install()
                NSLog("HookSocketServer: repaired incomplete hook registration")
            } catch {
                NSLog("HookSocketServer: failed to repair hook registration - %@", error.localizedDescription)
            }
        }

        let server = HookSocketServer()
        do {
            try server.start(
                eventHandler: { [weak self] event in
                    self?.store.processHookEvent(event)
                    self?.refreshCoordinator.syncSoundStateAfterHookEvent()
                },
                connectionHandler: { connected in
                    NSLog("HookSocketServer: hook connected=%@", String(connected))
                },
                disconnectionHandler: { [weak self] reason in
                    NSLog("HookSocketServer: hook disconnected: %@", reason)
                    self?.notifyHookDisconnected()
                }
            )
            self.hookSocketServer = server
            NSLog("HookSocketServer: started successfully")
        } catch {
            NSLog("HookSocketServer: failed to start - %@", error.localizedDescription)
        }
    }

    private var hookDisconnectedAlertShown = false

    private func notifyHookDisconnected() {
        // Only log once per app session to avoid spam.
        // The app continues running on AppleScript observation fallback.
        guard !hookDisconnectedAlertShown else { return }
        hookDisconnectedAlertShown = true

        NSLog("HookSocketServer: hook disconnected, falling back to AppleScript observation")
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
