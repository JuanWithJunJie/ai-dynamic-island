import Foundation
import MacIrlandKit

@MainActor
final class RefreshCoordinator {
    private let store: TaskStateStore
    private let interval: TimeInterval
    private var timer: Timer?

    init(store: TaskStateStore, interval: TimeInterval = 1.0) {
        self.store = store
        self.interval = interval
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.store.refresh()
            }
        }
        timer?.tolerance = 0.2
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
