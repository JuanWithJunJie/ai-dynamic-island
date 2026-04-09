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

    public init(
        observationService: any ObservationProviding = MockObservationService(),
        sessionResolver: SessionResolver = SessionResolver(),
        aggregationEngine: TaskAggregationEngine = TaskAggregationEngine(),
        replyBridge: any ReplyBridging = MockReplyBridgeService(),
        permissionService: any PermissionProviding = PlaceholderPermissionService(),
        localStore: any LocalStoring = InMemoryLocalStore(),
        registry: AdapterRegistry = AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
    ) {
        self.observationService = observationService
        self.sessionResolver = sessionResolver
        self.aggregationEngine = aggregationEngine
        self.replyBridge = replyBridge
        self.permissionService = permissionService
        self.localStore = localStore
        self.registry = registry
        self.automationPermissionService = permissionService as? AutomationPermissionService
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

    public var selectedSession: TaskSession? {
        guard let selectedSessionID else {
            return topSession
        }

        return sessions.first(where: { $0.id == selectedSessionID }) ?? topSession
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
        let existingByID = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })

        return refreshedSessions.map { refreshedSession in
            guard let existingSession = existingByID[refreshedSession.id] else {
                return refreshedSession
            }

            var mergedHistory = existingSession.historyEntries
            if existingSession.status != refreshedSession.status,
               let latestEntry = refreshedSession.historyEntries.last {
                mergedHistory.append(latestEntry)
            }

            return refreshedSession.withHistoryEntries(mergedHistory)
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
