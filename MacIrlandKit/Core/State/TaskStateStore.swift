import Foundation
import Observation

@MainActor
@Observable
public final class TaskStateStore {
    public private(set) var sessions: [TaskSession]
    public private(set) var summary: AppTaskSummary
    public private(set) var capabilityStatus: CapabilityStatus
    public var soundMode: SoundMode
    public var draftReply: String

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
        self.draftReply = ""
        self.capabilityStatus = permissionService.currentStatus()

        let resolved = sessionResolver.resolveSessions(from: observationService.latestEvents(), using: registry)
        self.sessions = aggregationEngine.prioritize(resolved)
        self.summary = aggregationEngine.summary(for: self.sessions)
    }

    public var topSession: TaskSession? {
        sessions.first
    }

    public func refresh() {
        capabilityStatus = permissionService.currentStatus()
        sessions = aggregationEngine.prioritize(
            sessionResolver.resolveSessions(from: observationService.latestEvents(), using: registry)
        )
        summary = aggregationEngine.summary(for: sessions)
    }

    public func update(soundMode: SoundMode) {
        self.soundMode = soundMode
        localStore.save(soundMode: soundMode)
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
}
