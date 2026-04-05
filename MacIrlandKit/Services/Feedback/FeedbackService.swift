import Foundation

public protocol FeedbackProviding: Sendable {
    func cues(for sessions: [TaskSession]) -> [SoundCue]
}

public struct FeedbackService: FeedbackProviding {
    public init() {}

    public func cues(for sessions: [TaskSession]) -> [SoundCue] {
        var cues: [SoundCue] = []

        if sessions.contains(where: { $0.status == .running }) {
            cues.append(.taskStarted)
        }
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
}
