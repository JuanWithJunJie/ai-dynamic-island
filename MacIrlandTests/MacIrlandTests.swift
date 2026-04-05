import Foundation
import Testing
@testable import MacIrlandKit

private final class MutableObservationModeSource: @unchecked Sendable {
    var mode: ObservationMode

    init(mode: ObservationMode) {
        self.mode = mode
    }
}

@MainActor
@Test func taskAggregationSummaryCountsStates() {
    let store = TaskStateStore(
        observationService: MockObservationService(),
        sessionResolver: SessionResolver(),
        aggregationEngine: TaskAggregationEngine(),
        replyBridge: MockReplyBridgeService(),
        permissionService: PlaceholderPermissionService(),
        localStore: InMemoryLocalStore(),
        registry: AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
    )

    #expect(store.sessions.count == 3)
    #expect(store.summary.runningCount == 1)
    #expect(store.summary.waitingCount == 1)
    #expect(store.summary.completedCount == 1)
    #expect(store.topSession?.status == .waitingInput)
    #expect(store.topSession?.attentionLevel == .needsReply)
    #expect(store.recentHistory.count == 1)
    #expect(store.recentHistory.first?.status == .completed)
}

@Test func replyValidationRequiresMessageAndSafeCapability() {
    let bridge = MockReplyBridgeService()
    let session = BuiltInCLIAdapter.codex.buildSession(
        from: RawCLIEvent(
            cliKind: .codex,
            snippet: "reply required",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Codex task",
                commandLine: "codex",
                ttyIdentifier: nil
            )
        )
    )!

    let emptyValidation = bridge.validateReply(for: session, message: "   ")
    #expect(emptyValidation.canSend == false)

    let nonEmptyValidation = bridge.validateReply(for: session, message: "继续")
    #expect(nonEmptyValidation.canSend == false)
    #expect(nonEmptyValidation.explanation.contains("真实桥接"))
}

@Test func fallbackSessionShowsIdleState() {
    let fallback = MockData.sampleFallbackSession
    #expect(fallback.sourceCLI == .unknown)
    #expect(fallback.status == .discovered)
    #expect(fallback.attentionLevel == .passive)
    #expect(fallback.recoverySuggestion != nil)
}

@Test func timelineObservationCyclesThroughPrototypeStates() {
    let base = Date(timeIntervalSince1970: 9)
    let waitingService = MockObservationService(mode: .timeline, now: { base })
    let replyService = MockObservationService(mode: .timeline, now: { base.addingTimeInterval(1) })
    let alertService = MockObservationService(mode: .timeline, now: { base.addingTimeInterval(2) })

    let waitingSessions = SessionResolver().resolveSessions(
        from: waitingService.latestEvents(),
        using: AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
    )
    let replySessions = SessionResolver().resolveSessions(
        from: replyService.latestEvents(),
        using: AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
    )
    let alertSessions = SessionResolver().resolveSessions(
        from: alertService.latestEvents(),
        using: AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
    )

    #expect(waitingSessions.contains(where: { $0.status == .waitingInput }))
    #expect(replySessions.contains(where: { $0.status == .replyAvailable }))
    #expect(alertSessions.contains(where: { $0.status == .alert }))
    #expect(alertSessions.contains(where: { $0.recoverySuggestion != nil }))
}

@MainActor
@Test func storeLoadsPrototypeControlsFromLocalStore() {
    let store = TaskStateStore(
        observationService: MockObservationService(mode: .fixed),
        localStore: InMemoryLocalStore(
            initialMode: .mute,
            initialObservationMode: .fixed,
            initialAutoRefreshInterval: 11
        )
    )

    #expect(store.soundMode == .mute)
    #expect(store.observationMode == .fixed)
    #expect(store.autoRefreshInterval == 11)
    #expect(store.autoRefreshLabel == "每 11 秒自动刷新")
}

@MainActor
@Test func updatingPrototypeControlsPersistsAndSwitchesObservationSource() {
    let localStore = InMemoryLocalStore(initialObservationMode: .timeline, initialAutoRefreshInterval: 4)
    let modeSource = MutableObservationModeSource(mode: localStore.loadObservationMode())
    let store = TaskStateStore(
        observationService: MockObservationService(
            modeProvider: { modeSource.mode },
            now: { Date(timeIntervalSince1970: 10) }
        ),
        localStore: localStore
    )

    store.update(autoRefreshInterval: 1)
    #expect(store.autoRefreshInterval == 2)
    #expect(localStore.loadAutoRefreshInterval() == 2)

    store.update(autoRefreshInterval: 99)
    #expect(store.autoRefreshInterval == 12)
    #expect(localStore.loadAutoRefreshInterval() == 12)

    let timelineStatuses = Set(store.sessions.map(\.status))
    #expect(timelineStatuses.contains(.replyAvailable))

    modeSource.mode = .fixed
    store.update(observationMode: .fixed)

    #expect(store.observationMode == .fixed)
    #expect(localStore.loadObservationMode() == .fixed)
    #expect(store.sessions.contains(where: { $0.status == .waitingInput }))
    #expect(store.sessions.contains(where: { $0.status == .running }))
    #expect(store.sessions.contains(where: { $0.status == .completed }))
    #expect(store.sessions.contains(where: { $0.status == .replyAvailable }) == false)
}
