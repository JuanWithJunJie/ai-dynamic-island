import Foundation

public protocol ObservationProviding: Sendable {
    func latestEvents() -> [RawCLIEvent]
}

public enum ObservationMode: String, CaseIterable, Codable, Sendable {
    case fixed
    case timeline

    public var title: String {
        switch self {
        case .fixed:
            return "静态样例"
        case .timeline:
            return "动态轮播"
        }
    }

    public var description: String {
        switch self {
        case .fixed:
            return "保持一组稳定的 mock 任务，便于检查布局和文案。"
        case .timeline:
            return "自动轮播等待输入、可回复和告警场景，更接近真实体验。"
        }
    }
}

public struct MockObservationService: ObservationProviding {
    private let modeProvider: @Sendable () -> ObservationMode
    private let now: @Sendable () -> Date

    public init(
        mode: ObservationMode = .fixed,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.modeProvider = { mode }
        self.now = now
    }

    public init(
        modeProvider: @escaping @Sendable () -> ObservationMode,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.modeProvider = modeProvider
        self.now = now
    }

    public func latestEvents() -> [RawCLIEvent] {
        switch modeProvider() {
        case .fixed:
            return MockData.sampleEvents
        case .timeline:
            return MockData.timelineEvents(at: now())
        }
    }
}
