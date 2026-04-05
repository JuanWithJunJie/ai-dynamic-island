import Foundation

public protocol ObservationProviding: Sendable {
    func latestEvents() -> [RawCLIEvent]
}

public struct MockObservationService: ObservationProviding {
    public enum Mode: Sendable {
        case fixed
        case timeline
    }

    private let mode: Mode
    private let now: @Sendable () -> Date

    public init(
        mode: Mode = .fixed,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.mode = mode
        self.now = now
    }

    public func latestEvents() -> [RawCLIEvent] {
        switch mode {
        case .fixed:
            return MockData.sampleEvents
        case .timeline:
            return MockData.timelineEvents(at: now())
        }
    }
}
