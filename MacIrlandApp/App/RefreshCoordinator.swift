import Foundation
import MacIrlandKit

@MainActor
final class RefreshCoordinator {
    private let store: TaskStateStore
    private let interval: TimeInterval
    private var timer: Timer?
    private var isRefreshing = false
    private let feedbackService: FeedbackService
    private let soundPlayer: SoundPlaying
    private var previousSessions: [TaskSession] = []
    // Tracks which sessions have already triggered .completed sound to prevent duplicates
    private var completedSoundPlayedForSessions: Set<TaskSession.ID> = []

    init(store: TaskStateStore, interval: TimeInterval = 1.0, soundPlayer: SoundPlaying? = nil) {
        self.store = store
        self.interval = interval
        self.feedbackService = FeedbackService()
        self.soundPlayer = soundPlayer ?? ChiptuneSoundPlayer()
    }

    func start() {
        stop()
        // Capture initial state
        previousSessions = store.sessions
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRefreshing == false else { return }
                self.isRefreshing = true
                defer { self.isRefreshing = false }
                self.store.refresh()
                self.playSoundCuesIfNeeded()
            }
        }
        timer?.tolerance = 0.2
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func syncSoundStateAfterHookEvent() {
        playSoundCuesIfNeeded()
    }

    private func playSoundCuesIfNeeded() {
        let currentSessions = store.sessions
        let cues = feedbackService.cues(previousSessions: previousSessions, currentSessions: currentSessions)
        let mode = store.soundMode

        // Clean up: remove sessions that no longer exist from tracking set
        let currentSessionIDs = Set(currentSessions.map { $0.id })
        completedSoundPlayedForSessions = completedSoundPlayedForSessions.filter { currentSessionIDs.contains($0) }

        // Allow the user-facing handoff cue as well, but keep taskStarted muted.
        // Deduplicate .completed cues to prevent multiple triggers (only play once per session).
        var completedSoundPlayedThisCycle: Set<TaskSession.ID> = []
        for cue in cues {
            guard cue == .waitingForReply || cue == .completed || cue == .failed else { continue }

            if cue == .completed {
                // Find sessions that transitioned to completed this cycle and haven't played yet
                for session in currentSessions where session.status == .completed {
                    if !completedSoundPlayedForSessions.contains(session.id) &&
                       !completedSoundPlayedThisCycle.contains(session.id) {
                        soundPlayer.playIfAllowed(cue, mode: mode)
                        completedSoundPlayedThisCycle.insert(session.id)
                        completedSoundPlayedForSessions.insert(session.id)
                        break  // Only one .completed sound per cycle
                    }
                }
            } else {
                soundPlayer.playIfAllowed(cue, mode: mode)
            }
        }
        // Update previous sessions for next comparison
        previousSessions = currentSessions
    }
}
