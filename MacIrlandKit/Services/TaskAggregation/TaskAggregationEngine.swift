import Foundation

public struct TaskAggregationEngine: Sendable {
    public init() {}

    public func prioritize(_ sessions: [TaskSession]) -> [TaskSession] {
        sessions.sorted {
            if $0.priority == $1.priority {
                return $0.lastActiveAt > $1.lastActiveAt
            }
            return $0.priority > $1.priority
        }
    }

    public func summary(for sessions: [TaskSession]) -> AppTaskSummary {
        AppTaskSummary(
            runningCount: sessions.filter { $0.status == .running }.count,
            waitingCount: sessions.filter { $0.status == .waitingInput || $0.status == .replyAvailable }.count,
            completedCount: sessions.filter { $0.status == .completed }.count,
            alertCount: sessions.filter { $0.status == .alert || $0.status == .failed }.count,
            topPrioritySessionID: prioritize(sessions).first?.id
        )
    }
}
