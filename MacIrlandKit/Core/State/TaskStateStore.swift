import Foundation
import Observation

@MainActor
@Observable
public final class TaskStateStore {
    public private(set) var sessions: [TaskSession]
    public private(set) var summary: AppTaskSummary
    public private(set) var capabilityStatus: CapabilityStatus
    public private(set) var lastRefreshAt: Date
    public var soundMode: SoundMode
    public var draftReply: String
    public var observationMode: ObservationMode
    public var autoRefreshInterval: TimeInterval

    private let observationService: any ObservationProviding
    private let sessionResolver: SessionResolver
    private let aggregationEngine: TaskAggregationEngine
    private let replyBridge: any ReplyBridging
    private let permissionService: any PermissionProviding
    private let localStore: any LocalStoring
    private let registry: AdapterRegistry

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
        self.soundMode = localStore.loadSoundMode()
        self.observationMode = localStore.loadObservationMode()
        self.autoRefreshInterval = Self.clampedRefreshInterval(localStore.loadAutoRefreshInterval())
        self.draftReply = ""
        self.capabilityStatus = permissionService.currentStatus()
        self.lastRefreshAt = .now

        let resolved = sessionResolver.resolveSessions(from: observationService.latestEvents(), using: registry)
        let prioritizedSessions = aggregationEngine.prioritize(resolved)
        self.sessions = prioritizedSessions
        self.summary = aggregationEngine.summary(for: prioritizedSessions)
    }

    public var topSession: TaskSession? {
        sessions.first
    }

    public var recentHistory: [TaskSession] {
        sessions
            .filter { $0.status.isTerminal || $0.status == .alert }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
            .prefix(3)
            .map { $0 }
    }

    public var autoRefreshLabel: String {
        let seconds = Int(autoRefreshInterval)
        return "每 \(seconds) 秒自动刷新"
    }

    public func refresh() {
        capabilityStatus = permissionService.currentStatus()
        sessions = aggregationEngine.prioritize(
            sessionResolver.resolveSessions(from: observationService.latestEvents(), using: registry)
        )
        summary = aggregationEngine.summary(for: sessions)
        lastRefreshAt = .now
    }

    public func update(soundMode: SoundMode) {
        self.soundMode = soundMode
        localStore.save(soundMode: soundMode)
    }

    public func update(observationMode: ObservationMode) {
        self.observationMode = observationMode
        localStore.save(observationMode: observationMode)
        refresh()
    }

    public func update(autoRefreshInterval: TimeInterval) {
        let clamped = Self.clampedRefreshInterval(autoRefreshInterval)
        self.autoRefreshInterval = clamped
        localStore.save(autoRefreshInterval: clamped)
    }

    public func performQuickAction(_ action: ReplyActionType, for session: TaskSession) -> ReplyValidationResult {
        let message = action == .customText ? draftReply : action.defaultMessage
        return replyBridge.validateReply(for: session, message: message)
    }

    public func sendDraftReply(for session: TaskSession) -> ReplyValidationResult {
        let result = replyBridge.sendReply(to: session, message: draftReply)
        if result.canSend {
            draftReply = ""
        }
        return result
    }

    private static func clampedRefreshInterval(_ value: TimeInterval) -> TimeInterval {
        min(max(value, 2), 12)
    }
}
