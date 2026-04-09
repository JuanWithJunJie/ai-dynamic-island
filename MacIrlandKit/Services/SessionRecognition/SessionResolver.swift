import Foundation

public struct SessionResolver: Sendable {
    public init() {}

    public func resolveSessions(
        from events: [RawCLIEvent],
        using registry: AdapterRegistry
    ) -> [TaskSession] {
        let candidates = events.compactMap { event -> TaskSession? in
            let adapter = registry.adapter(for: event.snapshot) ?? registry.adapters.first(where: { $0.cliKind == event.cliKind })
            return adapter?.buildSession(from: event)
        }

        var dedupedByID: [TaskSession.ID: TaskSession] = [:]
        for session in candidates {
            guard let existing = dedupedByID[session.id] else {
                dedupedByID[session.id] = session
                continue
            }

            if session.lastActiveAt > existing.lastActiveAt {
                dedupedByID[session.id] = session
            } else if session.lastActiveAt == existing.lastActiveAt, session.priority > existing.priority {
                dedupedByID[session.id] = session
            }
        }

        return Array(dedupedByID.values)
    }
}
