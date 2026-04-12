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

            // Prefer higher attention tier when timestamps are equal (true duplicates
            // from the same observation snapshot). This ensures attention sessions
            // are not accidentally collapsed by weaker states during rapid updates.
            if session.lastActiveAt == existing.lastActiveAt {
                let sessionTier = TaskStatus.tier(for: session.status)
                let existingTier = TaskStatus.tier(for: existing.status)
                if sessionTier > existingTier {
                    dedupedByID[session.id] = session
                } else if sessionTier == existingTier, session.priority > existing.priority {
                    dedupedByID[session.id] = session
                }
            } else if session.lastActiveAt > existing.lastActiveAt {
                dedupedByID[session.id] = session
            }
        }

        return Array(dedupedByID.values)
    }
}
