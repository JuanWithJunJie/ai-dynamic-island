import Foundation

public protocol FeedbackProviding: Sendable {
    func cues(for sessions: [TaskSession]) -> [SoundCue]
    func cues(previousSessions: [TaskSession], currentSessions: [TaskSession]) -> [SoundCue]
}

public struct FeedbackService: FeedbackProviding {
    public init() {}

    /// Legacy method for non-transition-aware usage
    public func cues(for sessions: [TaskSession]) -> [SoundCue] {
        var cues: [SoundCue] = []

        if sessions.contains(where: { $0.status == .waitingInput || $0.status == .replyAvailable }) {
            cues.append(.waitingForReply)
        }
        if sessions.contains(where: { $0.status == .completed }) {
            cues.append(.completed)
        }
        if sessions.contains(where: { $0.status == .alert || $0.status == .failed }) {
            cues.append(.failed)
        }

        return cues
    }

    /// Transition-aware cue generation: only emit cues when sessions enter new states
    public func cues(previousSessions: [TaskSession], currentSessions: [TaskSession]) -> [SoundCue] {
        var cues: [SoundCue] = []

        // Build lookup for previous session states by ID
        let previousByID = Dictionary(uniqueKeysWithValues: previousSessions.map { ($0.id, $0.status) })

        for current in currentSessions {
            let previousStatus = previousByID[current.id]

            // Session transitioned to waitingInput or replyAvailable
            if (current.status == .waitingInput || current.status == .replyAvailable) &&
               previousStatus != .waitingInput && previousStatus != .replyAvailable {
                cues.append(.waitingForReply)
            }

            // Session transitioned to completed
            if current.status == .completed && previousStatus != .completed {
                cues.append(.completed)
            }

            // Session transitioned to alert or failed
            if (current.status == .alert || current.status == .failed) &&
               previousStatus != .alert && previousStatus != .failed {
                cues.append(.failed)
            }
        }

        return cues
    }
}
