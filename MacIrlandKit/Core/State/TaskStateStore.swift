import Foundation
import Observation

@Observable
public final class TaskStateStore {
    public private(set) var sessions: [TaskSession]
    public private(set) var summary: AppTaskSummary
    public private(set) var capabilityStatus: CapabilityStatus
    public private(set) var observationDiagnostics: ObservationDiagnostics
    public private(set) var selectedSessionID: TaskSession.ID?
    public var soundMode: SoundMode
    public var draftReply: String {
        didSet {
            guard let selectedSessionID else {
                return
            }

            if draftReply.isEmpty {
                draftRepliesBySessionID.removeValue(forKey: selectedSessionID)
            } else {
                draftRepliesBySessionID[selectedSessionID] = draftReply
            }
        }
    }

    private var draftRepliesBySessionID: [TaskSession.ID: String]
    private let observationService: any ObservationProviding
    private let sessionResolver: SessionResolver
    private let aggregationEngine: TaskAggregationEngine
    private let replyBridge: any ReplyBridging
    private let permissionService: any PermissionProviding
    private let localStore: any LocalStoring
    private let registry: AdapterRegistry
    private let automationPermissionService: AutomationPermissionService?
    private let _hookSoundPlayer: SoundPlaying?

    public init(
        observationService: any ObservationProviding = MockObservationService(),
        sessionResolver: SessionResolver = SessionResolver(),
        aggregationEngine: TaskAggregationEngine = TaskAggregationEngine(),
        replyBridge: any ReplyBridging = MockReplyBridgeService(),
        permissionService: any PermissionProviding = PlaceholderPermissionService(),
        localStore: any LocalStoring = InMemoryLocalStore(),
        registry: AdapterRegistry = AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini]),
        hookSoundPlayer: SoundPlaying? = nil
    ) {
        self.observationService = observationService
        self.sessionResolver = sessionResolver
        self.aggregationEngine = aggregationEngine
        self.replyBridge = replyBridge
        self.permissionService = permissionService
        self.localStore = localStore
        self.registry = registry
        self.automationPermissionService = permissionService as? AutomationPermissionService
        self._hookSoundPlayer = hookSoundPlayer
        self.soundMode = localStore.loadSoundMode()
        self.draftRepliesBySessionID = [:]
        self.draftReply = ""
        self.capabilityStatus = permissionService.currentStatus()
        self.observationDiagnostics = ObservationDiagnostics(readers: [], sessions: [])

        let initialSnapshot = observationService.latestSnapshot()
        let initialEvents = initialSnapshot.events
        let resolved = sessionResolver.resolveSessions(from: initialEvents, using: registry)
        let prioritizedSessions = aggregationEngine.prioritize(resolved)
        let initialSummary = aggregationEngine.summary(for: prioritizedSessions)
        self.sessions = prioritizedSessions
        self.summary = initialSummary
        self.selectedSessionID = prioritizedSessions.first?.id
        self.draftReply = prioritizedSessions.first.flatMap { draftRepliesBySessionID[$0.id] } ?? ""
        self.observationDiagnostics = initialSnapshot.diagnostics
        self.capabilityStatus = capabilityStatus(for: initialEvents, resolvedSessions: prioritizedSessions)
    }

    public var topSession: TaskSession? {
        sessions.first
    }

    public var preferredIslandSession: TaskSession? {
        sessions.max { a, b in
            let tierA = TaskStatus.tier(for: a.status)
            let tierB = TaskStatus.tier(for: b.status)
            if tierA != tierB {
                return tierA < tierB
            }
            if a.priority != b.priority {
                return a.priority < b.priority
            }
            return a.lastActiveAt < b.lastActiveAt
        }
    }

    public var islandAttentionSessions: [TaskSession] {
        sessions
            .filter { $0.status.needsAttention }
            .sorted { a, b in
                let tierA = TaskStatus.tier(for: a.status)
                let tierB = TaskStatus.tier(for: b.status)
                if tierA != tierB {
                    return tierA > tierB
                }
                if a.priority != b.priority {
                    return a.priority > b.priority
                }
                return a.lastActiveAt > b.lastActiveAt
            }
    }

    public func secondaryIslandAttentionCount(excluding sessionID: TaskSession.ID?) -> Int {
        guard let currentFocusID = sessionID else {
            return islandAttentionSessions.count
        }
        return islandAttentionSessions.filter { $0.id != currentFocusID }.count
    }

    /// Returns true when there are multiple relevant CLI sessions that would benefit
    /// from the multi-session tray for quick switching.
    ///
    /// A "relevant" session means:
    /// - Not in a terminal state (completed, failed, contextLost)
    /// - AND either:
    ///   - Claude Code CLI (primary target), OR
    ///   - Has high confidence AND a bridge target (indicating active engagement)
    ///
    /// This is smarter than raw `sessions.count > 1` because it filters out:
    /// - Completed/terminal sessions that are just sitting around
    /// - Low-confidence or unconnected sessions that aren't really "working"
    public var hasMultipleRelevantSessions: Bool {
        traySessions.count > 1
    }

    /// Returns the sessions that should appear in the multi-session tray.
    /// This is the single source of truth for both tray eligibility and tray row content.
    ///
    /// Filtering criteria (Claude-first):
    /// - Not in a terminal state (completed, failed, contextLost)
    /// - AND Claude Code CLI (primary target)
    ///
    /// Note: Non-Claude sessions (Codex, Gemini) are excluded from tray to keep
    /// the tray behavior focused on the primary product target.
    public var traySessions: [TaskSession] {
        sessions.filter { session in
            // Exclude terminal states
            guard !session.status.isTerminal else { return false }

            // Only Claude Code sessions are relevant for tray (Claude-first)
            return session.sourceCLI == .claudeCode
        }
    }

    /// Claude-first session source for hover expand.
    ///
    /// Unlike traySessions, this keeps completed Claude sessions visible so the
    /// compact count, primary hover detail, and secondary hover rows all describe
    /// the same session universe during a short post-run window.
    public var hoverExpandSessions: [TaskSession] {
        sessions.filter { $0.sourceCLI == .claudeCode }
    }

    public var hoverExpandPrimarySession: TaskSession? {
        if let preferredIslandSession,
           hoverExpandSessions.contains(where: { $0.id == preferredIslandSession.id }) {
            return preferredIslandSession
        }

        return hoverExpandSessions.first
    }

    public var hoverExpandSecondarySessions: [TaskSession] {
        guard let primaryID = hoverExpandPrimarySession?.id else {
            return hoverExpandSessions
        }

        return hoverExpandSessions.filter { $0.id != primaryID }
    }

    public var hoverExpandSessionCount: Int {
        hoverExpandSessions.count
    }

    /// Returns the sessions that should appear in the panel's primary surface.
    /// This is the source of truth for panel header, primary detail view, and session picker.
    ///
    /// Filtering criteria (Claude-first):
    /// - Not in a terminal state (completed, failed, contextLost)
    /// - AND Claude Code CLI (primary product target)
    ///
    /// This filter drives the main product layer. Non-Claude sessions remain
    /// observable via diagnostics but do not appear in the primary panel surface.
    public var primaryPanelSessions: [TaskSession] {
        sessions.filter { session in
            guard !session.status.isTerminal else { return false }
            return session.sourceCLI == .claudeCode
        }
    }

    /// Returns the best session to show in the panel's primary area.
    /// Prefers the currently selected session if it is still primary panel-eligible,
    /// otherwise falls back to the top primary session.
    public var selectedSession: TaskSession? {
        if let selectedSessionID {
            // Return selected session if it's still primary panel-eligible
            if let current = sessions.first(where: { $0.id == selectedSessionID }),
               primaryPanelSessions.contains(where: { $0.id == selectedSessionID }) {
                return current
            }
            // Fall back to top primary session
            return primaryPanelSessions.first
        }
        return primaryPanelSessions.first
    }

    public func refresh() {
        let snapshot = observationService.latestSnapshot()
        let latestEvents = snapshot.events
        let refreshedSessions = aggregationEngine.prioritize(
            sessionResolver.resolveSessions(from: latestEvents, using: registry)
        )
        let mergedSessions = mergeHistory(from: sessions, into: refreshedSessions)
        observationDiagnostics = snapshot.diagnostics
        capabilityStatus = capabilityStatus(for: latestEvents, resolvedSessions: mergedSessions)
        sessions = mergedSessions
        summary = aggregationEngine.summary(for: mergedSessions)
        reconcileSelection(with: mergedSessions)
    }

    // MARK: - Hook Event Processing

    private var hookCompletedSoundPlayedForSessions: Set<TaskSession.ID> = []

    /// Processes a hook event from HookSocketServer and updates the matching session.
    ///
    /// Hook events are the authoritative source for Claude Code session status.
    /// This method finds the session by hookSessionID or tty identifier, updates its status,
    /// and triggers appropriate sound cues.
    public func processHookEvent(_ event: HookEvent) {
        // Debug logging
        var logLines = ["processHookEvent: sessionID=\(event.sessionID) tty=\(event.tty) event=\(String(describing: event.event)) hookStatus=\(String(describing: event.hookStatus)) sessionsCount=\(sessions.count)"]
        for (i, s) in sessions.enumerated() {
            logLines.append("  session[\(i)]: tty=\(s.identity.ttyIdentifier ?? "nil") hookSessionID=\(s.identity.hookSessionID ?? "nil") status=\(s.status)")
        }
        let logText = logLines.joined(separator: "\n") + "\n"
        if let data = logText.data(using: .utf8),
           let file = FileHandle(forWritingAtPath: "/tmp/macirland-hook-debug.log") {
            file.seekToEndOfFile()
            file.write(data)
            file.closeFile()
        }

        // Find session by hookSessionID first (exact match on Claude Code session ID)
        // Then fall back to tty matching
        var sessionIndex: Int?
        var needsHookSessionIDUpdate = false

        if let hookSessionID = event.sessionID.nilIfEmpty {
            // Try to find by hookSessionID
            sessionIndex = sessions.firstIndex { $0.identity.hookSessionID == hookSessionID }
        }

        // Fall back to tty matching ONLY if existing session has no hookSessionID yet.
        // If existing session already has hookSessionID set (even if different from this event's),
        // it is a distinct session with its own identity — do NOT use as a match.
        if sessionIndex == nil {
            if let existingWithTty = sessions.first(where: { $0.identity.ttyIdentifier == event.tty }) {
                // Only use tty match if existing session has no hookSessionID yet.
                // If hookSessionID is already set (even if different), it's a distinct session.
                if existingWithTty.identity.hookSessionID == nil {
                    sessionIndex = sessions.firstIndex { $0.identity.ttyIdentifier == event.tty }
                    needsHookSessionIDUpdate = true
                }
                // If existing session HAS hookSessionID set, leave sessionIndex = nil → will create new session
            }
            // If no tty match found, sessionIndex stays nil → will create new session
        }

        // No existing session found — create a new hook-first session
        guard let idx = sessionIndex else {
            // Debug logging
            if let data = "  -> Creating new hook-first session\n".data(using: .utf8),
               let file = FileHandle(forWritingAtPath: "/tmp/macirland-hook-debug.log") {
                file.seekToEndOfFile()
                file.write(data)
                file.closeFile()
            }

            let newSession = createHookFirstSession(from: event)
            var updatedSessions = sessions
            updatedSessions.append(newSession)
            updatedSessions = aggregationEngine.prioritize(updatedSessions)
            sessions = updatedSessions
            summary = aggregationEngine.summary(for: updatedSessions)
            return
        }

        let session = sessions[idx]
        let previousStatus = session.status

        // Convert hook status to task status
        let newStatus: TaskStatus
        switch event.hookStatus {
        case .idle:
            // Idle events don't change status
            return
        case .running:
            newStatus = .running
        case .waitingForReply:
            newStatus = .waitingInput
        case .completed:
            newStatus = .completed
        }

        // Build updated session
        var updatedSession = session

        // If session doesn't have hookSessionID yet, update it
        if needsHookSessionIDUpdate, let hookSID = event.sessionID.nilIfEmpty {
            let updatedIdentity = SessionIdentity(
                id: session.identity.id,
                cliKind: session.identity.cliKind,
                terminalAppIdentifier: session.identity.terminalAppIdentifier,
                windowIdentifier: session.identity.windowIdentifier,
                commandLine: session.identity.commandLine,
                ttyIdentifier: session.identity.ttyIdentifier,
                hookSessionID: hookSID,
                sessionName: session.identity.sessionName,
                startedAt: session.identity.startedAt,
                lastSeenAt: session.identity.lastSeenAt
            )
            updatedSession = TaskSession(
                id: session.id,
                identity: updatedIdentity,
                title: session.title,
                status: newStatus,
                priority: session.priority,
                confidence: session.confidence,
                summary: session.summary,
                bridgeTarget: session.bridgeTarget,
                replyCapability: session.replyCapability,
                lastActiveAt: Date(),
                evidence: session.evidence,
                recentEvents: session.recentEvents,
                recentMessages: session.recentMessages,
                historyEntries: session.historyEntries,
                quickActions: session.quickActions
            )
        } else {
            updatedSession = TaskSession(
                id: session.id,
                identity: session.identity,
                title: session.title,
                status: newStatus,
                priority: session.priority,
                confidence: session.confidence,
                summary: session.summary,
                bridgeTarget: session.bridgeTarget,
                replyCapability: session.replyCapability,
                lastActiveAt: Date(),
                evidence: session.evidence,
                recentEvents: session.recentEvents,
                recentMessages: session.recentMessages,
                historyEntries: session.historyEntries,
                quickActions: session.quickActions
            )
        }

        // Handle SessionEnd: clean up completed session after a delay
        if event.event == .sessionEnd {
            // Mark as completed immediately, history entry added below
        }

        // Append history entry for hook-driven status change
        let historyEntry = SessionHistoryEntry(
            kind: historyKindFor(status: newStatus),
            title: "Hook: \(event.event.rawValue)",
            detail: "cwd: \(event.cwd), tool: \(event.tool ?? "none")",
            relatedStatus: newStatus
        )
        var updatedHistoryEntries = updatedSession.historyEntries
        updatedHistoryEntries.append(historyEntry)

        updatedSession = TaskSession(
            id: updatedSession.id,
            identity: updatedSession.identity,
            title: updatedSession.title,
            status: newStatus,
            priority: updatedSession.priority,
            confidence: updatedSession.confidence,
            summary: updatedSession.summary,
            bridgeTarget: updatedSession.bridgeTarget,
            replyCapability: updatedSession.replyCapability,
            lastActiveAt: updatedSession.lastActiveAt,
            evidence: updatedSession.evidence,
            recentEvents: updatedSession.recentEvents,
            recentMessages: updatedSession.recentMessages,
            historyEntries: updatedHistoryEntries,
            quickActions: updatedSession.quickActions
        )

        // Update sessions array
        var updatedSessions = sessions
        updatedSessions[idx] = updatedSession


        // Recalculate summary and priority
        updatedSessions = aggregationEngine.prioritize(updatedSessions)
        sessions = updatedSessions
        summary = aggregationEngine.summary(for: updatedSessions)

        // Emit sound cue for status transition (hook-driven deduplication)
        emitHookSoundCue(previousStatus: previousStatus, newStatus: newStatus, sessionID: session.id)
    }

    private func emitHookSoundCue(previousStatus: TaskStatus, newStatus: TaskStatus, sessionID: TaskSession.ID) {
        let cue: SoundCue?
        switch newStatus {
        case .waitingInput, .replyAvailable:
            cue = (previousStatus != .waitingInput && previousStatus != .replyAvailable) ? .waitingForReply : nil
        case .completed:
            if !hookCompletedSoundPlayedForSessions.contains(sessionID) {
                cue = .completed
                hookCompletedSoundPlayedForSessions.insert(sessionID)
            } else {
                cue = nil
            }
        case .alert, .failed:
            cue = (previousStatus != .alert && previousStatus != .failed) ? .failed : nil
        default:
            cue = nil
        }

        // Debug logging for sound cue
        let debugMsg = "emitHookSoundCue: cue=\(cue?.rawValue ?? "nil"), mode=\(soundMode.rawValue), player=\(_hookSoundPlayer != nil ? "set" : "nil"), previousStatus=\(previousStatus), newStatus=\(newStatus)"
        if let data = (debugMsg + "\n").data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/macirland-sound-debug.log"))
        }

        guard let cue, let player = _hookSoundPlayer else { return }
        player.playIfAllowed(cue, mode: soundMode)
    }

    /// Creates a new TaskSession directly from a HookEvent, without requiring AppleScript observation.
    ///
    /// Hook events are the authoritative source for Claude Code session identity. This method
    /// creates a session with a stable ID derived from hookSessionID + terminalAppIdentifier,
    /// ensuring AppleScript-observed sessions for the same logical session can merge via
    /// the same tty-based identity key.
    private func createHookFirstSession(from event: HookEvent) -> TaskSession {
        // Derive stable session ID from hookSessionID and terminal app.
        // Using hookSessionID as primary identity key makes hook-first sessions
        // unique and prevents AppleScript observation from creating duplicates
        // when it later sees the same session.
        let terminalAppIdentifier = terminalAppIdentifier(for: event.tty)

        // Compute stable ID using the same algorithm as BuiltInCLIAdapter.buildSession.
        // This ensures hook-created and AppleScript-created sessions for the same
        // terminal will have the same TaskSession.ID and naturally merge.
        let stableID = BuiltInCLIAdapter.computeStableSessionID(
            cliKind: .claudeCode,
            terminalAppIdentifier: terminalAppIdentifier,
            ttyIdentifier: event.tty
        )

        // Build identity with hook-derived fields
        let identity = SessionIdentity(
            id: stableID,
            cliKind: .claudeCode,
            terminalAppIdentifier: terminalAppIdentifier,
            windowIdentifier: event.tty,
            commandLine: "",
            ttyIdentifier: event.tty,
            hookSessionID: event.sessionID.nilIfEmpty,
            sessionName: "",
            startedAt: Date(),
            lastSeenAt: Date()
        )

        // Convert hook status to task status
        let newStatus: TaskStatus
        switch event.hookStatus {
        case .idle:
            newStatus = .running
        case .running:
            newStatus = .running
        case .waitingForReply:
            newStatus = .waitingInput
        case .completed:
            newStatus = .completed
        }

        // Derive title from cwd (last path component = project signal)
        let projectName = URL(fileURLWithPath: event.cwd).lastPathComponent
        let title = projectName.isEmpty ? "Claude Code" : projectName

        // Build evidence from hook event
        let evidence = [
            EvidenceItem(
                sourceType: .bridge,
                summary: "Hook event: \(event.event.rawValue)",
                rawSnippet: "tty: \(event.tty), cwd: \(event.cwd), tool: \(event.tool ?? "none")",
                weight: 0.95
            )
        ]

        // Build recent event
        let recentEvents = [
            SessionEvent(kind: eventKindFor(hookEvent: event), message: event.status)
        ]

        // Reply capability based on terminal type
        let replyCapability: ReplyCapability
        switch terminalAppIdentifier {
        case "com.apple.Terminal":
            replyCapability = ReplyCapability(
                status: .available,
                reason: "Hook-first session with Terminal",
                targetDescription: "Claude Code",
                channelStatus: "applescript-terminal"
            )
        case "com.googlecode.iterm2":
            replyCapability = ReplyCapability(
                status: .available,
                reason: "Hook-first session with iTerm2",
                targetDescription: "Claude Code",
                channelStatus: "applescript-iterm"
            )
        default:
            replyCapability = ReplyCapability(
                status: .manualConfirmationRequired,
                reason: "Hook-first session",
                targetDescription: "Claude Code",
                channelStatus: "dynamic"
            )
        }

        // Initial history entry for hook-driven creation
        let initialHistoryEntry = SessionHistoryEntry(
            timestamp: Date(),
            kind: historyKindFor(status: newStatus),
            title: "Hook: \(event.event.rawValue)",
            detail: "cwd: \(event.cwd), tool: \(event.tool ?? "none")",
            relatedStatus: newStatus
        )

        return TaskSession(
            id: identity.id,
            identity: identity,
            title: title,
            status: newStatus,
            priority: priorityForHookStatus(newStatus),
            confidence: 0.95, // Hook events are authoritative
            summary: "\(event.status) — \(event.cwd)",
            bridgeTarget: BridgeTarget(
                cliKind: .claudeCode,
                sessionID: identity.id,
                terminalContext: event.tty,
                channelType: terminalAppIdentifier == "com.apple.Terminal" ? "applescript-terminal" : "applescript-iterm",
                displayName: "Claude Code · \(title)"
            ),
            replyCapability: replyCapability,
            lastActiveAt: Date(),
            evidence: evidence,
            recentEvents: recentEvents,
            recentMessages: [],
            historyEntries: [initialHistoryEntry],
            quickActions: BuiltInCLIAdapter.claudeCode.supportedQuickActions
        )
    }

    private func eventKindFor(hookEvent: HookEvent) -> SessionEventKind {
        switch hookEvent.hookStatus {
        case .running:
            return .started
        case .waitingForReply:
            return .waitingForInput
        case .completed:
            return .completed
        case .idle:
            return .started
        }
    }

    private func priorityForHookStatus(_ status: TaskStatus) -> Int {
        switch status {
        case .waitingInput:
            return 95
        case .replyAvailable:
            return 100
        case .alert, .failed:
            return 90
        case .running:
            return 70
        case .completed:
            return 40
        default:
            return 50
        }
    }

    private func terminalAppIdentifier(for tty: String) -> String {
        // Infer terminal app from tty path
        if tty.contains("ttys") && !tty.contains("pts") {
            // Standard macOS pty names: /dev/ttysXXX → Terminal
            return "com.apple.Terminal"
        } else if tty.contains("pts") {
            // /dev/pts/X → typically iTerm2 or other
            return "com.googlecode.iterm2"
        }
        return "com.apple.Terminal" // default
    }

    private func historyKindFor(status: TaskStatus) -> SessionHistoryKind {
        switch status {
        case .running: return .phaseRunning
        case .waitingInput: return .phaseWaitingInput
        case .replyAvailable: return .phaseReplyAvailable
        case .completed: return .phaseCompleted
        case .alert: return .phaseAlert
        case .failed: return .phaseFailed
        case .contextLost: return .phaseContextLost
        default: return .phaseDiscovered
        }
    }

    public func selectSession(_ session: TaskSession) {
        selectSession(id: session.id)
    }

    public func selectSession(id: TaskSession.ID?) {
        let nextSelectedID: TaskSession.ID?
        if let id {
            guard sessions.contains(where: { $0.id == id }) else {
                return
            }
            nextSelectedID = id
        } else {
            nextSelectedID = sessions.first?.id
        }

        selectedSessionID = nextSelectedID
        draftReply = nextSelectedID.flatMap { draftRepliesBySessionID[$0] } ?? ""
    }

    public func update(soundMode: SoundMode) {
        self.soundMode = soundMode
        localStore.save(soundMode: soundMode)
    }

    public func performQuickAction(_ action: ReplyActionType, for session: TaskSession) -> ReplyValidationResult {
        let message = action == .customText ? draftReply : action.defaultMessage
        let result = replyBridge.sendReply(to: session, message: message)
        let entry = SessionHistoryEntry(
            kind: result.canSend ? .userQuickAction : .userReplyRejected,
            title: result.canSend ? action.title : "回复被拒绝",
            detail: result.canSend ? message : result.explanation,
            relatedStatus: session.status
        )
        appendHistoryEntry(entry, toSessionWithID: session.id)
        if result.canSend {
            draftRepliesBySessionID.removeValue(forKey: session.id)
            if selectedSessionID == session.id {
                draftReply = ""
            }
        }
        return result
    }

    public func sendDraftReply(for session: TaskSession) -> ReplyValidationResult {
        let result = replyBridge.sendReply(to: session, message: draftReply)
        let entry = SessionHistoryEntry(
            kind: result.canSend ? .userCustomReply : .userReplyRejected,
            title: result.canSend ? ReplyActionType.customText.title : "回复被拒绝",
            detail: result.canSend ? draftReply : result.explanation,
            relatedStatus: session.status
        )
        appendHistoryEntry(entry, toSessionWithID: session.id)
        if result.canSend {
            draftRepliesBySessionID.removeValue(forKey: session.id)
            if selectedSessionID == session.id {
                draftReply = ""
            }
        }
        return result
    }

    private func appendHistoryEntry(_ entry: SessionHistoryEntry, toSessionWithID sessionID: TaskSession.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        let session = sessions[index]
        var historyEntries = session.historyEntries
        historyEntries.append(entry)
        sessions[index] = session.withHistoryEntries(historyEntries)
    }

    private func reconcileSelection(with sessions: [TaskSession]) {
        if let selectedSessionID,
           sessions.contains(where: { $0.id == selectedSessionID }) {
            return
        }

        selectedSessionID = sessions.first?.id
        draftReply = selectedSessionID.flatMap { draftRepliesBySessionID[$0] } ?? ""
    }

    private func mergeHistory(from existingSessions: [TaskSession], into refreshedSessions: [TaskSession]) -> [TaskSession] {
        // Defensive: build dictionary without crashing on duplicate IDs
        // If duplicates exist, keep the session with newer lastActiveAt
        var existingByID: [TaskSession.ID: TaskSession] = [:]
        for session in existingSessions {
            if let existing = existingByID[session.id] {
                if session.lastActiveAt > existing.lastActiveAt {
                    existingByID[session.id] = session
                }
            } else {
                existingByID[session.id] = session
            }
        }

        return refreshedSessions.map { refreshedSession in
            // Primary matching: by TaskSession.ID
            guard let existingSession = existingByID[refreshedSession.id] else {
                // Fallback matching: when hook-created session (with hookSessionID) and
                // AppleScript-created session (without hookSessionID) have the same tty,
                // they are the same logical session and should merge.
                // The hook-derived ID and hookSessionID must be preserved.
                //
                // Canonical identity chain: hookSessionID > (terminalAppIdentifier + tty) > text fallback
                // This fallback implements step 2: when hookSessionID is not available in the
                // AppleScript observation, use tty as the matching key.
                if let hookSession = existingSessions.first(where: { existing in
                    // Existing session must have hookSessionID set (hook-created)
                    // Refreshed session must NOT have hookSessionID (AppleScript-created)
                    // They must have the same tty (same logical session)
                    existing.identity.hookSessionID != nil
                    && refreshedSession.identity.hookSessionID == nil
                    && existing.identity.ttyIdentifier == refreshedSession.identity.ttyIdentifier
                    && existing.identity.ttyIdentifier != nil
                }) {
                    // Merge: preserve hook-derived ID and hookSessionID, merge data from refreshedSession
                    var mergedSession = TaskSession(
                        id: hookSession.id,  // Preserve hook-derived ID
                        identity: SessionIdentity(
                            id: hookSession.identity.id,
                            cliKind: refreshedSession.identity.cliKind,
                            terminalAppIdentifier: refreshedSession.identity.terminalAppIdentifier,
                            windowIdentifier: refreshedSession.identity.windowIdentifier,
                            commandLine: refreshedSession.identity.commandLine,
                            ttyIdentifier: refreshedSession.identity.ttyIdentifier,
                            hookSessionID: hookSession.identity.hookSessionID,  // Preserve hookSessionID
                            sessionName: refreshedSession.identity.sessionName,
                            startedAt: hookSession.identity.startedAt,
                            lastSeenAt: refreshedSession.identity.lastSeenAt
                        ),
                        title: refreshedSession.title,
                        status: refreshedSession.status,
                        priority: refreshedSession.priority,
                        confidence: refreshedSession.confidence,
                        summary: refreshedSession.summary,
                        bridgeTarget: refreshedSession.bridgeTarget,
                        replyCapability: refreshedSession.replyCapability,
                        lastActiveAt: refreshedSession.lastActiveAt,
                        evidence: refreshedSession.evidence,
                        recentEvents: refreshedSession.recentEvents,
                        recentMessages: refreshedSession.recentMessages,
                        historyEntries: hookSession.historyEntries,
                        quickActions: refreshedSession.quickActions
                    )

                    // Preserve hook-driven completed status
                    if hookSession.status == .completed,
                       (refreshedSession.status == .running || refreshedSession.status == .waitingInput || refreshedSession.status == .alert) {
                        mergedSession = TaskSession(
                            id: mergedSession.id,
                            identity: mergedSession.identity,
                            title: mergedSession.title,
                            status: .completed,
                            priority: mergedSession.priority,
                            confidence: mergedSession.confidence,
                            summary: mergedSession.summary,
                            bridgeTarget: mergedSession.bridgeTarget,
                            replyCapability: mergedSession.replyCapability,
                            lastActiveAt: mergedSession.lastActiveAt,
                            evidence: mergedSession.evidence,
                            recentEvents: mergedSession.recentEvents,
                            recentMessages: mergedSession.recentMessages,
                            historyEntries: mergedSession.historyEntries,
                            quickActions: mergedSession.quickActions
                        )
                    }

                    var mergedHistory = mergedSession.historyEntries
                    if hookSession.status != mergedSession.status,
                       let latestEntry = refreshedSession.historyEntries.last {
                        mergedHistory.append(latestEntry)
                    }

                    return mergedSession.withHistoryEntries(mergedHistory)
                }

                // No match found - return refreshed session as-is (new session)
                return refreshedSession
            }

            // Preserve hook-driven identity: if existing session has hookSessionID but
            // refreshed session doesn't (AppleScript didn't see it), preserve hookSessionID.
            // This ensures hook-created sessions retain their identity through merges.
            var mergedIdentity = refreshedSession.identity
            if existingSession.identity.hookSessionID != nil
               && refreshedSession.identity.hookSessionID == nil {
                mergedIdentity = SessionIdentity(
                    id: refreshedSession.identity.id,
                    cliKind: refreshedSession.identity.cliKind,
                    terminalAppIdentifier: refreshedSession.identity.terminalAppIdentifier,
                    windowIdentifier: refreshedSession.identity.windowIdentifier,
                    commandLine: refreshedSession.identity.commandLine,
                    ttyIdentifier: refreshedSession.identity.ttyIdentifier,
                    hookSessionID: existingSession.identity.hookSessionID,
                    sessionName: refreshedSession.identity.sessionName,
                    startedAt: existingSession.identity.startedAt,
                    lastSeenAt: refreshedSession.identity.lastSeenAt
                )
            }

            // Preserve hook-driven status: if existing session is completed but observation
            // reports running/waiting/alert, keep the hook-driven completed status.
            // Alert can override completed if the existing session is NOT completed
            // (i.e., observation detected a real alert condition).
            var mergedSession = TaskSession(
                id: mergedIdentity.id,
                identity: mergedIdentity,
                title: refreshedSession.title,
                status: refreshedSession.status,
                priority: refreshedSession.priority,
                confidence: refreshedSession.confidence,
                summary: refreshedSession.summary,
                bridgeTarget: refreshedSession.bridgeTarget,
                replyCapability: refreshedSession.replyCapability,
                lastActiveAt: refreshedSession.lastActiveAt,
                evidence: refreshedSession.evidence,
                recentEvents: refreshedSession.recentEvents,
                recentMessages: refreshedSession.recentMessages,
                historyEntries: refreshedSession.historyEntries,
                quickActions: refreshedSession.quickActions
            )
            if existingSession.status == .completed,
               (refreshedSession.status == .running || refreshedSession.status == .waitingInput || refreshedSession.status == .alert) {
                mergedSession = TaskSession(
                    id: mergedSession.id,
                    identity: mergedSession.identity,
                    title: mergedSession.title,
                    status: .completed,
                    priority: mergedSession.priority,
                    confidence: mergedSession.confidence,
                    summary: mergedSession.summary,
                    bridgeTarget: mergedSession.bridgeTarget,
                    replyCapability: mergedSession.replyCapability,
                    lastActiveAt: existingSession.lastActiveAt,
                    evidence: mergedSession.evidence,
                    recentEvents: mergedSession.recentEvents,
                    recentMessages: mergedSession.recentMessages,
                    historyEntries: mergedSession.historyEntries,
                    quickActions: mergedSession.quickActions
                )
            }

            var mergedHistory = existingSession.historyEntries
            if existingSession.status != mergedSession.status,
               let latestEntry = mergedSession.historyEntries.last {
                mergedHistory.append(latestEntry)
            }

            return mergedSession.withHistoryEntries(mergedHistory)
        }
    }

    private func capabilityStatus(for events: [RawCLIEvent], resolvedSessions: [TaskSession]) -> CapabilityStatus {
        let baseStatus = permissionService.currentStatus()
        guard let automationPermissionService else {
            return baseStatus
        }

        let hasTerminalAppsRunning = AutomationPermissionService.areSupportedTerminalAppsRunning()
        let observationBlocked = hasTerminalAppsRunning && events.isEmpty && resolvedSessions.isEmpty
        return automationPermissionService.status(terminalAppsDetected: hasTerminalAppsRunning, observationBlocked: observationBlocked)
    }
}
