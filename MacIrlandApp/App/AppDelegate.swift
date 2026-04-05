import AppKit
import Observation
import MacIrlandKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStateStore(observationService: MockObservationService(mode: .timeline))

    private var panelCoordinator: PanelCoordinator?
    private var statusBarController: StatusBarController?
    private var sessionTracking: Any?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelCoordinator = PanelCoordinator(store: store)
        let statusBarController = StatusBarController(session: store.topSession) {
            panelCoordinator.togglePanel()
        }

        self.panelCoordinator = panelCoordinator
        self.statusBarController = statusBarController
        startSessionTracking()
        startRefreshTimer()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func startSessionTracking() {
        sessionTracking = withObservationTracking {
            _ = store.topSession
            _ = store.summary
            _ = store.lastRefreshAt
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusBarController?.update(session: self?.store.topSession)
                self?.startSessionTracking()
            }
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.store.refresh()
            }
        }
    }
}
