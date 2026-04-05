import Foundation

public protocol ObservationProviding: Sendable {
    func latestEvents() -> [RawCLIEvent]
}

public struct MockObservationService: ObservationProviding {
    public init() {}

    public func latestEvents() -> [RawCLIEvent] {
        MockData.sampleEvents
    }
}
