import AppKit
import Observation
import MacIrlandKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStateStore()

    private var panelCoordinator: PanelCoordinator?
    private var statusBarController: StatusBarController?
    private var sessionTracking: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelCoordinator = PanelCoordinator(store: store)
        let statusBarController = StatusBarController(session: store.topSession) {
            panelCoordinator.togglePanel()
        }

        self.panelCoordinator = panelCoordinator
        self.statusBarController = statusBarController
        self.sessionTracking = withObservationTracking {
            _ = store.topSession
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusBarController?.update(session: self?.store.topSession)
                self?.startSessionTracking()
            }
        }
        NSApp.setActivationPolicy(.accessory)
    }

    private func startSessionTracking() {
        sessionTracking = withObservationTracking {
            _ = store.topSession
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusBarController?.update(session: self?.store.topSession)
                self?.startSessionTracking()
            }
        }
    }
}
