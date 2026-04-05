import Foundation

public struct SessionResolver: Sendable {
    public init() {}

    public func resolveSessions(
        from events: [RawCLIEvent],
        using registry: AdapterRegistry
    ) -> [TaskSession] {
        events.compactMap { event in
            let adapter = registry.adapter(for: event.snapshot) ?? registry.adapters.first(where: { $0.cliKind == event.cliKind })
            return adapter?.buildSession(from: event)
        }
    }
}
