import AppKit
import Observation
import MacIrlandKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let localStore = InMemoryLocalStore(initialObservationMode: .timeline)
    private lazy var observationService = MockObservationService(modeProvider: { [weak self] in
        self?.localStore.loadObservationMode() ?? .timeline
    })
    lazy var store = TaskStateStore(
        observationService: observationService,
        localStore: localStore
    )

    private var panelCoordinator: PanelCoordinator?
    private var statusBarController: StatusBarController?
    private var sessionTracking: Any?
    private var refreshIntervalTracking: Any?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelCoordinator = PanelCoordinator(store: store)
        let statusBarController = StatusBarController(session: store.topSession) {
            panelCoordinator.togglePanel()
        }

        self.panelCoordinator = panelCoordinator
        self.statusBarController = statusBarController
        startSessionTracking()
        startRefreshIntervalTracking()
        startRefreshTimer()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func startSessionTracking() {
        sessionTracking = withObservationTracking({
            _ = store.topSession
            _ = store.summary
            _ = store.lastRefreshAt
            return store.lastRefreshAt
        }, onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusBarController?.update(session: self?.store.topSession)
                self?.startSessionTracking()
            }
        })
    }

    private func startRefreshIntervalTracking() {
        refreshIntervalTracking = withObservationTracking({
            _ = store.autoRefreshInterval
            return store.autoRefreshInterval
        }, onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.startRefreshTimer()
                self?.startRefreshIntervalTracking()
            }
        })
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: store.autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.store.refresh()
            }
        }
    }
}
