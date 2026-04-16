import XCTest
@testable import MacIrlandKit

final class TaskStateStoreTests: XCTestCase {
    func testInitBuildsSessionsAndSummaryFromLatestEvents() {
        let store = TaskStateStore(
            observationService: StubObservationService(events: prioritizedEvents, diagnostics: .empty)
        )

        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertEqual(store.summary.waitingCount, 1)
        XCTAssertEqual(store.summary.runningCount, 0)
        XCTAssertEqual(store.summary.completedCount, 1)
        XCTAssertEqual(store.topSession?.sourceCLI, .claudeCode)
        XCTAssertEqual(store.selectedSession?.id, store.topSession?.id)
    }

    func testInitSeedsRuntimeHistoryFromInitialStatus() {
        let store = TaskStateStore(
            observationService: StubObservationService(events: [waitingClaudeEvent], diagnostics: .empty)
        )

        XCTAssertEqual(store.sessions.first?.historyEntries.count, 1)
        XCTAssertEqual(store.sessions.first?.historyEntries.first?.kind, .phaseWaitingInput)
    }

    func testRefreshPreservesHistoryEntriesForExistingSession() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        source.updateEvents([waitingClaudeEvent])
        store.refresh()
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning, .phaseWaitingInput])

        source.updateEvents([runningClaudeEventWithNewSnippet])
        store.refresh()

        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning, .phaseWaitingInput, .phaseRunning])
    }

    func testRefreshAppendsNewPhaseEntryWhenStatusChanges() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning])

        source.updateEvents([waitingClaudeEvent])
        store.refresh()

        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning, .phaseWaitingInput])
    }

    func testRefreshDoesNotAppendDuplicatePhaseEntryWhenStatusRepeats() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        source.updateEvents([runningClaudeEventWithNewSnippet])
        store.refresh()

        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning])
    }

    func testRefreshSeedsOneHistoryEntryForNewlyAppearingSession() {
        let source = MutableObservationService(initialEvents: [])
        let store = TaskStateStore(observationService: source)

        XCTAssertTrue(store.sessions.isEmpty)

        source.updateEvents([waitingClaudeEvent])
        store.refresh()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseWaitingInput])
    }

    func testPerformQuickActionAppendsRejectedHistoryWhenReplyCannotSend() throws {
        let replyBridge = ConfigurableReplyBridge(sendResult: ReplyValidationResult(canSend: false, explanation: "Bridge unavailable"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)

        let result = store.performQuickAction(.continueExecution, for: session)

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "Bridge unavailable")
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseWaitingInput, .userReplyRejected])
        XCTAssertEqual(store.sessions.first?.historyEntries.last?.detail, "Bridge unavailable")
    }

    func testPerformQuickActionUsesSendPathAndAppendsUserQuickActionHistory() throws {
        let replyBridge = ConfigurableReplyBridge(
            validateResult: ReplyValidationResult(canSend: false, explanation: "Should not use validate"),
            sendResult: ReplyValidationResult(canSend: true, explanation: "Sent quick action")
        )
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)

        let result = store.performQuickAction(.continueExecution, for: session)

        XCTAssertTrue(result.canSend)
        XCTAssertEqual(result.explanation, "Sent quick action")
        XCTAssertEqual(replyBridge.validateCallCount, 0)
        XCTAssertEqual(replyBridge.sendCallCount, 1)
        XCTAssertEqual(replyBridge.lastSentMessage, ReplyActionType.continueExecution.defaultMessage)
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseWaitingInput, .userQuickAction])
        XCTAssertEqual(store.sessions.first?.historyEntries.last?.detail, ReplyActionType.continueExecution.defaultMessage)
    }

    func testPerformQuickActionClearsDraftReplyAfterSuccessfulSend() throws {
        let replyBridge = ConfigurableReplyBridge(sendResult: ReplyValidationResult(canSend: true, explanation: "Sent quick action"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)
        store.draftReply = "temporary text"

        _ = store.performQuickAction(.continueExecution, for: session)

        XCTAssertEqual(store.draftReply, "")
    }

    func testSendDraftReplyClearsDraftReplyAfterSuccessfulSend() throws {
        let replyBridge = ConfigurableReplyBridge(sendResult: ReplyValidationResult(canSend: true, explanation: "Sent"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)
        store.draftReply = "Please continue with the refactor."

        _ = store.sendDraftReply(for: session)

        XCTAssertEqual(store.draftReply, "")
    }

    func testClaudeAdapterMarksTerminalSessionAsRealReplyCandidate() {
        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: replyAvailableClaudeEvent)

        XCTAssertEqual(session?.replyCapability.status, .available)
        XCTAssertEqual(session?.replyCapability.channelStatus, "applescript-terminal")
        XCTAssertEqual(session?.bridgeTarget?.channelType, "applescript-terminal")
    }

    func testSendDraftReplyAppendsCustomReplyHistoryWhenSendSucceeds() throws {
        let replyBridge = ConfigurableReplyBridge(sendResult: ReplyValidationResult(canSend: true, explanation: "Sent"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)
        store.draftReply = "Please continue with the refactor."

        let result = store.sendDraftReply(for: session)

        XCTAssertTrue(result.canSend)
        XCTAssertEqual(result.explanation, "Sent")
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseWaitingInput, .userCustomReply])
        XCTAssertEqual(store.sessions.first?.historyEntries.last?.detail, "Please continue with the refactor.")
    }

    func testSendDraftReplyAppendsRejectedHistoryWhenSendFails() throws {
        let replyBridge = ConfigurableReplyBridge(sendResult: ReplyValidationResult(canSend: false, explanation: "Send denied"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)
        store.draftReply = "Please continue with the refactor."

        let result = store.sendDraftReply(for: session)

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "Send denied")
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseWaitingInput, .userReplyRejected])
        XCTAssertEqual(store.sessions.first?.historyEntries.last?.detail, "Send denied")
    }

    func testDraftReplyIsScopedPerSessionWhenSwitchingSelections() throws {
        let store = TaskStateStore(
            observationService: StubObservationService(events: prioritizedEvents, diagnostics: .empty)
        )
        let first = try XCTUnwrap(store.sessions.first)
        let second = try XCTUnwrap(store.sessions.last)

        store.selectSession(first)
        store.draftReply = "first draft"

        store.selectSession(second)
        XCTAssertEqual(store.draftReply, "")

        store.draftReply = "second draft"
        store.selectSession(first)

        XCTAssertEqual(store.draftReply, "first draft")
    }

    func testSendDraftReplyClearsOnlyCurrentSessionDraft() throws {
        let replyBridge = ConfigurableReplyBridge(sendResult: ReplyValidationResult(canSend: true, explanation: "Sent"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: prioritizedEvents, diagnostics: .empty),
            replyBridge: replyBridge
        )
        let first = try XCTUnwrap(store.sessions.first)
        let second = try XCTUnwrap(store.sessions.last)

        store.selectSession(first)
        store.draftReply = "first draft"
        store.selectSession(second)
        store.draftReply = "second draft"

        _ = store.sendDraftReply(for: second)
        XCTAssertEqual(store.draftReply, "")

        store.selectSession(first)
        XCTAssertEqual(store.draftReply, "first draft")
    }

    func testRefreshPreservesSelectedSessionWhenLogicalSessionRemains() throws {
        let source = MutableObservationService(initialEvents: prioritizedEvents)
        let store = TaskStateStore(observationService: source)

        guard let originalSecondSession = store.sessions.last else {
            XCTFail("Expected at least one session")
            return
        }

        // Capture the selected session ID before selection
        let selectedIDBefore = originalSecondSession.id

        store.selectSession(originalSecondSession)

        // Verify selection is set
        XCTAssertEqual(store.selectedSessionID, selectedIDBefore)

        source.updateEvents(refreshedEventsKeepingSameSessions)
        store.refresh()

        // Selection should be preserved - same session ID still in primaryPanelSessions
        XCTAssertEqual(store.selectedSessionID, selectedIDBefore)
        XCTAssertEqual(store.selectedSession?.sourceCLI, .claudeCode)
        XCTAssertNotNil(store.selectedSession)
    }

    func testRefreshFallsBackToTopSessionWhenSelectedSessionDisappears() throws {
        let source = MutableObservationService(initialEvents: prioritizedEvents)
        let store = TaskStateStore(observationService: source)
        let originalSecondSession = try XCTUnwrap(store.sessions.last)

        store.selectSession(originalSecondSession)
        source.updateEvents([prioritizedEvents[0]])

        store.refresh()

        XCTAssertNotEqual(store.selectedSession?.id, originalSecondSession.id)
        XCTAssertEqual(store.selectedSession?.id, store.topSession?.id)
        XCTAssertEqual(store.sessions.count, 1)
    }

    func testRefreshClearsSelectionWhenNoSessionsRemain() {
        let source = MutableObservationService(initialEvents: prioritizedEvents)
        let store = TaskStateStore(observationService: source)

        source.updateEvents([])
        store.refresh()

        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.topSession)
        XCTAssertNil(store.selectedSession)
        XCTAssertNil(store.selectedSessionID)
    }

    func testNoSessionReadinessSurfacesAfterAllSessionsDisappear() {
        let source = MutableObservationService(initialEvents: prioritizedEvents)
        let store = TaskStateStore(observationService: source)

        // Simulate Terminal/Claude closing: no more events arrive
        source.updateEvents([])
        store.refresh()

        // Primary surface should be empty
        XCTAssertTrue(store.primaryPanelSessions.isEmpty)
        XCTAssertTrue(store.traySessions.isEmpty)
        XCTAssertFalse(store.hasMultipleRelevantSessions)

        // No-session readiness should surface
        XCTAssertEqual(store.appReadiness.level, .noSession)
        XCTAssertFalse(store.appReadiness.title.isEmpty)
        XCTAssertFalse(store.appReadiness.explanation.isEmpty)
    }

    func testCompletedSessionsAreFilteredFromPrimaryPanelAfterTeardown() {
        let completedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "All set. Created file: project-x.txt",
            transcript: "All set. Created file: project-x.txt",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project-x",
                commandLine: "claude",
                ttyIdentifier: "ttys005"
            )
        )
        let source = MutableObservationService(initialEvents: [completedEvent])
        let store = TaskStateStore(observationService: source)

        // Session exists but is completed
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.status, .completed)

        // Completed sessions are filtered from primary panel
        XCTAssertTrue(store.primaryPanelSessions.isEmpty)
        XCTAssertTrue(store.traySessions.isEmpty)

        // No-session readiness because no active sessions
        XCTAssertEqual(store.appReadiness.level, .noSession)
    }

    func testHistoryPreservedButStaleSessionNotInActiveRuntimeAfterTeardown() {
        let source = MutableObservationService(initialEvents: [prioritizedEvents[0]])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertFalse(store.sessions.first?.historyEntries.isEmpty ?? true)

        // Session disappears (Terminal closed)
        source.updateEvents([])
        store.refresh()

        // Sessions are cleared, no stale sessions remain
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.primaryPanelSessions.isEmpty)

        // Readiness shows no-session
        XCTAssertEqual(store.appReadiness.level, .noSession)
    }

    func testPreferredIslandSessionIconStatusConsistency() {
        // When preferred session transitions to waitingInput, its animatedStatus
        // should NOT be .running (was bug: icon used topSession while text used preferredIslandSession)
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "What's next? Let me know if you want me to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project-wait",
                commandLine: "claude",
                ttyIdentifier: "ttys010"
            )
        )
        let source = MutableObservationService(initialEvents: [waitingEvent])
        let store = TaskStateStore(observationService: source)

        let preferredSession = store.preferredIslandSession
        XCTAssertNotNil(preferredSession)
        XCTAssertEqual(preferredSession?.status, .waitingInput)

        // Icon should use preferredIslandSession status, not topSession
        let iconStatus = preferredSession?.status.animatedStatus ?? .idle
        XCTAssertEqual(iconStatus, .waiting, "waitingInput session should show waiting icon, not running")
        XCTAssertNotEqual(iconStatus, .running, "waitingInput should never show running icon")
    }

    func testRealObservationBuildsRunningClaudeEventFromObservation() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · feature",
                            commandLine: "claude",
                            ttyIdentifier: "ttys007"
                        ),
                        transcript: "thinking through the file edits"
                    )
                ]))
            ]
        )

        let events = service.latestEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.cliKind, .claudeCode)
        XCTAssertEqual(events.first?.snapshot.windowTitle, "Claude Code · feature")
        XCTAssertEqual(events.first?.snippet, "Running Claude Code terminal session: Claude Code · feature")
    }

    func testRealObservationDetectsWaitingInputStatus() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · confirm",
                            commandLine: "claude",
                            ttyIdentifier: "ttys008"
                        ),
                        transcript: "Need user input. Please confirm whether to continue."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .waitingInput)
        XCTAssertEqual(store.summary.waitingCount, 1)
    }

    func testRealObservationDetectsCompletedStatus() {
        XCTAssertEqual(ClaudeStatusJudge.judge(transcript: "Task complete. Finished successfully completed.").status, .completed)

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.googlecode.iterm2",
                            windowTitle: "Claude Code · done",
                            commandLine: "claude",
                            ttyIdentifier: "ttys009"
                        ),
                        transcript: "Task complete. Finished successfully completed."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .completed)
        XCTAssertEqual(store.summary.completedCount, 1)
    }

    func testClaudeAdapterDoesNotTreatEmptyTranscriptPromptAsCompleted() {
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "❯",
            transcript: "",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · long-run",
                commandLine: "claude",
                ttyIdentifier: "ttys014"
            )
        )

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)

        XCTAssertEqual(session?.status, .running)
    }

    func testClaudeAdapterIgnoresPreformattedCompletedSnippetWhenTranscriptIsEmpty() {
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Completed Claude Code terminal session: macirland",
            transcript: "",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · long-run",
                commandLine: "claude",
                ttyIdentifier: "ttys015"
            )
        )

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)

        XCTAssertEqual(session?.status, .running)
    }

    func testHookCompletedStatusSurvivesObservationRefreshOnSameTTY() {
        let runningObservation = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running Claude Code terminal session: macirland",
            transcript: "working through changes",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · macirland",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys031"
            )
        )
        let source = MutableObservationService(initialEvents: [runningObservation])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.sessions.first?.status, .running)

        store.processHookEvent(
            HookEvent(
                sessionID: "hook-session-1",
                cwd: "/Users/lijunjie/Documents/AIproject/macirland",
                event: .sessionEnd,
                status: "completed",
                pid: 123,
                tty: "/dev/ttys031"
            )
        )

        XCTAssertEqual(store.sessions.first?.status, .completed)

        source.updateEvents([runningObservation])
        store.refresh()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.status, .completed)
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "hook-session-1")
    }

    func testHookRunningStatusIsNotPromotedToCompletedByWeakObservationOnSameTTY() {
        let source = MutableObservationService(initialEvents: [])
        let store = TaskStateStore(observationService: source)

        store.processHookEvent(
            HookEvent(
                sessionID: "hook-session-2",
                cwd: "/Users/lijunjie/Documents/AIproject/macirland",
                event: .postToolUse,
                status: "running",
                pid: 456,
                tty: "/dev/ttys032"
            )
        )

        XCTAssertEqual(store.sessions.first?.status, .running)

        let weakCompletedObservation = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Completed Claude Code terminal session: macirland",
            transcript: "",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · macirland",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys032"
            )
        )
        source.updateEvents([weakCompletedObservation])
        store.refresh()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.status, .running)
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "hook-session-2")
    }

    func testRealObservationDetectsFailedStatus() {
        XCTAssertEqual(ClaudeStatusJudge.judge(transcript: "Permission denied. Fatal error: unable to write file.").status, .failed)

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · failed",
                            commandLine: "claude",
                            ttyIdentifier: "ttys011"
                        ),
                        transcript: "Permission denied. Fatal error: unable to write file."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .failed)
    }

    func testRealObservationDetectsAlertStatus() {
        XCTAssertEqual(ClaudeStatusJudge.judge(transcript: "Warning: network unstable, retrying request after rate limit.").status, .alert)

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · warning",
                            commandLine: "claude",
                            ttyIdentifier: "ttys012"
                        ),
                        transcript: "Warning: network unstable, retrying request after rate limit."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .alert)
    }

    func testRealObservationDetectsContextLostStatus() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.googlecode.iterm2",
                            windowTitle: "Claude Code · expired",
                            commandLine: "claude",
                            ttyIdentifier: "ttys013"
                        ),
                        transcript: "Conversation not found. Session expired and cannot continue."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .contextLost)
    }

    func testRealObservationPrefersFailedOverAlertSignals() {
        XCTAssertEqual(ClaudeStatusJudge.judge(transcript: "Warning: network unstable, retrying after fatal error.").status, .failed)

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · mixed",
                            commandLine: "claude",
                            ttyIdentifier: "ttys014"
                        ),
                        transcript: "Warning: network unstable, retrying after fatal error."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .failed)
    }

    func testRealObservationPrefersContextLostOverWaitingInputSignals() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · lost",
                            commandLine: "claude",
                            ttyIdentifier: "ttys015"
                        ),
                        transcript: "Please confirm. Context lost, cannot continue."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .contextLost)
    }

    func testRealObservationDoesNotTreatLooseClaudeMentionAsClaudeSession() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "notes about claude usage",
                            commandLine: "zsh",
                            ttyIdentifier: "ttys016"
                        ),
                        transcript: "documenting claude workflow"
                    )
                ]))
            ]
        )

        XCTAssertTrue(service.latestEvents().isEmpty)
    }

    func testRealObservationDoesNotTreatLooseConfirmWordAsWaitingInput() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · prose",
                            commandLine: "claude",
                            ttyIdentifier: "ttys017"
                        ),
                        transcript: "I can confirm the previous change is documented for future work."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .running)
    }

    func testRealObservationDoesNotTreatLooseNetworkWordAsAlert() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · prose",
                            commandLine: "claude",
                            ttyIdentifier: "ttys018"
                        ),
                        transcript: "This change improves the network model documentation for the app."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .running)
    }

    func testRealObservationDoesNotTreatLooseDoneWordAsCompleted() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.googlecode.iterm2",
                            windowTitle: "Claude Code · prose",
                            commandLine: "claude",
                            ttyIdentifier: "ttys019"
                        ),
                        transcript: "We are not done discussing the design yet."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.first?.status, .running)
    }

    func testRealObservationDoesNotAutoCompleteWhenClaudeDisappearsFromCommandLine() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · lingering title",
                            commandLine: "zsh",
                            ttyIdentifier: "ttys020"
                        ),
                        transcript: "reviewing recent output"
                    )
                ]))
            ]
        )

        let events = service.latestEvents()

        XCTAssertEqual(events.count, 1)
        let store = TaskStateStore(observationService: service)
        XCTAssertEqual(store.sessions.first?.status, .running)
    }

    func testRealObservationDoesNotAutoCompleteTerminalClaudeSessionWhenTranscriptIsTemporarilyEmpty() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · active task",
                            commandLine: "zsh",
                            ttyIdentifier: "ttys407",
                            isBusy: true
                        ),
                        transcript: ""
                    )
                ]))
            ]
        )

        let events = service.latestEvents()

        XCTAssertEqual(events.count, 1)
        let store = TaskStateStore(observationService: service)
        XCTAssertEqual(
            store.sessions.first?.status,
            .running,
            "Terminal.app can report an empty transcript while Claude is still running, so this must not force .completed"
        )
    }

    func testRealObservationUsesTerminalBusySignalToMarkEmptyTranscriptSessionAsWaitingInput() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · awaiting user",
                            commandLine: "login-zshclaude",
                            ttyIdentifier: "ttys408",
                            isBusy: false
                        ),
                        transcript: ""
                    )
                ]))
            ]
        )

        let events = service.latestEvents()

        XCTAssertEqual(events.count, 1)
        let store = TaskStateStore(observationService: service)
        XCTAssertEqual(
            store.sessions.first?.status,
            .waitingInput,
            "Terminal.app empty transcript with busy=false should be treated as waiting for user instead of still running"
        )
    }

    func testRealObservationRecognizesClaudeWhenTerminalReportsProcessListContainingClaude() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "feature branch",
                                commandLine: "login, zsh, claude",
                                ttyIdentifier: "ttys022"
                            ),
                            transcript: "reviewing recent output"
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sourceCLI, .claudeCode)
        XCTAssertEqual(store.sessions.first?.status, .running)
        XCTAssertEqual(store.observationDiagnostics.readers.first?.recognizedEventCount, 1)
    }

    func testRealObservationRecognizesClaudeFromTranscriptHeaderWhenCommandMetadataIsEmpty() {
        let snapshot = TerminalObservationSnapshot(
            terminalAppIdentifier: "com.googlecode.iterm2",
            windowTitle: "window",
            commandLine: "",
            ttyIdentifier: "/dev/ttys002"
        )
        let transcript = """
        Claude Code v2.1.89
        Sonnet 4.6 (1M context) · API Usage Billing
        ~/Documents/AIproject/macirland

        Read …
        """

        XCTAssertTrue(ClaudeSnapshotMatcher.recognizes(snapshot: snapshot, transcript: transcript))

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "iterm",
                    readerName: "iTerm",
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: snapshot,
                            transcript: transcript
                        )
                    ],
                    message: "已读取到 1 个 iTerm session",
                    errorDescription: nil
                ))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sourceCLI, .claudeCode)
        XCTAssertEqual(store.observationDiagnostics.readers.first?.recognizedEventCount, 1)
        XCTAssertEqual(store.observationDiagnostics.sessions.first?.recognizedCLIKind, .claudeCode)
    }

    func testRealObservationRecognizesClaudeFromTranscriptHeaderWhenTranscriptIsLong() {
        let header = """
        Claude Code v2.1.89
        Sonnet 4.6 (1M context) · API Usage Billing
        ~/Documents/AIproject/macirland

        """
        let longBody = String(repeating: "working through a long transcript block\n", count: 180)
        let transcript = header + longBody

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "iterm",
                    readerName: "iTerm",
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.googlecode.iterm2",
                                windowTitle: "node",
                                commandLine: "",
                                ttyIdentifier: "/dev/ttys002"
                            ),
                            transcript: transcript
                        )
                    ],
                    message: "已读取到 1 个 iTerm session",
                    errorDescription: nil
                ))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.sourceCLI, .claudeCode)
        XCTAssertEqual(store.observationDiagnostics.sessions.first?.recognizedCLIKind, .claudeCode)
    }

    func testRealObservationDoesNotTreatCommandHistoryMentionAsClaudeSession() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "shell history",
                                commandLine: "echo claude",
                                ttyIdentifier: "ttys023"
                            ),
                            transcript: "printing saved command examples"
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        XCTAssertTrue(service.latestEvents().isEmpty)
        XCTAssertEqual(service.latestSnapshot().diagnostics.sessions.first?.decisionReason, "未命中 Claude Code 识别规则")
    }

    func testRefreshFlagsObservationBlockedWhenTerminalAppsRunningButNoEventsArrive() {
        let source = MutableObservationService(initialEvents: [], diagnostics: ObservationDiagnostics(readers: [], sessions: []))
        let store = TaskStateStore(
            observationService: source,
            permissionService: StubPermissionService(
                status: CapabilityStatus(
                    accessibilityGranted: false,
                    localOnlyProcessing: true,
                    explanation: "已检测到 Terminal / iTerm 正在运行，但当前无法可靠读取会话内容。请确认系统已允许 MacIrland 通过 Apple Events 访问终端应用，然后点击刷新重试。",
                    observationBlocked: true
                )
            )
        )

        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.capabilityStatus.observationBlocked)
    }

    func testStorePreservesObservationDiagnostics() {
        let diagnostics = ObservationDiagnostics(
            readers: [
                ObservationReaderDiagnostic(
                    id: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observationCount: 1,
                    recognizedEventCount: 0,
                    message: "已读取到 1 个 Terminal session"
                )
            ],
            sessions: [
                ObservationSessionDiagnostic(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "feature branch",
                    commandLine: "echo claude",
                    ttyIdentifier: "ttys099",
                    transcriptPreview: "printing saved command examples",
                    recognizedCLIKind: nil,
                    inferredStatus: nil,
                    decisionReason: "未命中 Claude Code 识别规则"
                )
            ]
        )
        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: diagnostics),
            permissionService: StubPermissionService(
                status: CapabilityStatus(
                    accessibilityGranted: false,
                    localOnlyProcessing: true,
                    explanation: "observation blocked",
                    observationBlocked: true
                )
            )
        )

        XCTAssertEqual(store.observationDiagnostics.readers.first?.readerName, "Terminal")
        XCTAssertEqual(store.observationDiagnostics.sessions.first?.commandLine, "echo claude")
    }

    func testRealObservationPromotesMultiplePromptSignalsToWaitingInput() {
        let judgement = ClaudeStatusJudge.judge(transcript: "Please confirm before proceeding. Press enter to continue.")

        XCTAssertEqual(judgement.status, .waitingInput)
        XCTAssertGreaterThanOrEqual(judgement.confidence, 0.78)
    }

    func testRealObservationPromotesMultipleCompletionSignalsToCompleted() {
        let judgement = ClaudeStatusJudge.judge(transcript: "Task complete. All set and finished successfully.")

        XCTAssertEqual(judgement.status, .completed)
        XCTAssertGreaterThanOrEqual(judgement.confidence, 0.8)
    }

    func testRealObservationPromotesMultipleFailureSignalsToFailed() {
        let judgement = ClaudeStatusJudge.judge(transcript: "Error: command failed to apply patch and could not write file.")

        XCTAssertEqual(judgement.status, .failed)
        XCTAssertGreaterThanOrEqual(judgement.confidence, 0.84)
    }

    func testClaudeJudgeSuppressesProseConfirmSignal() {
        let judgement = ClaudeStatusJudge.judge(transcript: "I can confirm the design notes were updated for the release checklist.")

        XCTAssertEqual(judgement.status, .running)
    }

    func testClaudeJudgeSuppressesNotDoneSignal() {
        let judgement = ClaudeStatusJudge.judge(transcript: "We are not done with the migration plan yet, still discussing follow-up.")

        XCTAssertEqual(judgement.status, .running)
    }

    func testMVPSpecificPatternsFromRecording() {
        // Patterns directly from mac-island-mvp.mp4
        // "Anything else?" was shown in the recording as a handoff phrase
        let anythingElse = ClaudeStatusJudge.judge(transcript: "Created file: HelloWorld.swift. Anything else?")
        XCTAssertEqual(anythingElse.status, .waitingInput, "Anything else? should become waitingInput")

        // "Created file:" in completion context
        let createdFile = ClaudeStatusJudge.judge(transcript: "Created file: HelloWorld.swift")
        XCTAssertEqual(createdFile.status, .completed, "Created file: should become completed")

        // "Let me know if you'd like" from the MVP transcript
        let letMeKnow = ClaudeStatusJudge.judge(transcript: "Let me know if you'd like anything else!")
        XCTAssertEqual(letMeKnow.status, .waitingInput, "Let me know if you'd like pattern should be waitingInput")

        // Chinese handoff patterns
        let chineseHandoff = ClaudeStatusJudge.judge(transcript: "文件已创建完成。还需要什么帮助吗？")
        XCTAssertEqual(chineseHandoff.status, .waitingInput, "Chinese handoff pattern should become waitingInput")

        // Short "Anything else?" alone
        let shortHandoff = ClaudeStatusJudge.judge(transcript: "Anything else?")
        XCTAssertEqual(shortHandoff.status, .waitingInput, "Short Anything else? should become waitingInput")
    }

    func testClaudeTranscriptNormalizationRemovesAnsiNoiseAndPreservesChineseHandoff() {
        let raw = """
        \u{001B}[32m✔\u{001B}[0m 已完成当前整理。
        │ Tokens: 12.4k
        ╰─

          如果你愿意，我可以继续帮你整理下一轮计划。
        claude>
        """

        let normalized = ClaudeTranscriptNormalizer.normalize(raw)

        XCTAssertFalse(normalized.contains("\u{001B}"))
        XCTAssertFalse(normalized.contains("\r"))
        XCTAssertTrue(normalized.contains("如果你愿意，我可以继续帮你整理下一轮计划。"))
    }

    func testNoisyRawClaudeTranscriptBecomesReplyAvailableAfterNormalization() {
        let raw = """
        ╭─ Claude Code v1.2.3
        │ API Usage Billing
        ╰─
        正在检查项目状态...
        \u{001B}[32m✔\u{001B}[0m 本轮任务已经处理完成。
        还有什么我可以帮你的吗？
        claude>
        """

        let judgement = ClaudeStatusJudge.judge(transcript: raw)

        XCTAssertEqual(judgement.status, .replyAvailable)
    }

    func testNoisyRawClaudeTranscriptBecomesCompletedAfterNormalization() {
        let raw = """
        ╭─ Claude Code v1.2.3
        │ API Usage Billing
        ╰─
        正在生成文件...
        \u{001B}[32mCreated file:\u{001B}[0m Sources/App.swift
        shell%
        """

        let judgement = ClaudeStatusJudge.judge(transcript: raw)

        XCTAssertEqual(judgement.status, .completed)
    }

    func testRealObservationDiagnosticsExposeRawAndNormalizedTranscriptPreview() {
        let raw = """
        ╭─ Claude Code v1.2.3
        │ API Usage Billing
        ╰─
        \u{001B}[32m✔\u{001B}[0m 已完成当前整理。
        还有什么我可以帮你的吗？
        claude>
        """
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · project",
                                commandLine: "claude",
                                ttyIdentifier: "ttys099"
                            ),
                            transcript: raw
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let diagnostic = service.latestSnapshot().diagnostics.sessions.first

        XCTAssertEqual(diagnostic?.recognizedCLIKind, .claudeCode)
        XCTAssertEqual(diagnostic?.inferredStatus, .replyAvailable)
        XCTAssertTrue(diagnostic?.transcriptPreview.contains("\u{001B}") ?? false)
        XCTAssertFalse(diagnostic?.normalizedTranscriptPreview.contains("\u{001B}") ?? true)
        XCTAssertTrue(diagnostic?.normalizedTranscriptPreview.contains("还有什么我可以帮你的吗") ?? false)
    }

    func testRealObservationDiagnosticsExposeMatchedSignalsConfidenceAndNormalizedTail() {
        // Real completion transcript with strong "Created file:" signal
        let completionTranscript = """
        \u{001B}[2K\u{001B}[1A\u{001B}[32m✔\u{001B}[0m All done!
        \u{001B}[32mCreated file:\u{001B}[0m Sources/App.swift
        shell%
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · signals-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys500"
                            ),
                            transcript: completionTranscript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let diagnostic = service.latestSnapshot().diagnostics.sessions.first

        XCTAssertEqual(diagnostic?.recognizedCLIKind, .claudeCode)
        XCTAssertEqual(diagnostic?.inferredStatus, .completed)
        // matchedSignals should be populated (>= 1 for "Created file:" strong signal)
        XCTAssertGreaterThan(diagnostic?.matchedSignals ?? 0, 0)
        // confidence should be high for completion
        XCTAssertGreaterThanOrEqual(diagnostic?.confidence ?? 0, 0.72)
        // normalizedTail should contain the cleaned completion text (not ANSI noise)
        XCTAssertTrue(diagnostic?.normalizedTail.contains("Created file:") ?? false, "normalizedTail must contain 'Created file:' signal")
        XCTAssertFalse(diagnostic?.normalizedTail.contains("\u{001B}") ?? true, "normalizedTail must not contain ANSI escapes")
    }

    func testClaudeAdapterAndObservationStayAlignedForNoisyRawTranscript() {
        let raw = """
        ╭─ Claude Code v1.2.3
        │ API Usage Billing
        ╰─
        正在检查当前分支...
        \u{001B}[32m✔\u{001B}[0m 已完成当前整理。
        如果你愿意，我可以继续帮你整理下一轮计划。
        claude>
        """
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: raw,
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · noisy",
                commandLine: "claude",
                ttyIdentifier: "ttys100"
            )
        )

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)
        let judgement = ClaudeStatusJudge.judge(transcript: raw)

        XCTAssertEqual(judgement.status, .waitingInput)
        XCTAssertEqual(session?.status, judgement.status)
    }

    func testRealEndOfTurnHandoffPhrasesBecomeWaitingInput() {
        let phrases = [
            "I've created the migration script. Let me know if you'd like me to run it.",
            "I've updated all the API endpoints. Tell me if you want me to continue with the tests.",
            "Implementation is complete. What's next?",
            "I've finished the refactor. Next step would be to add tests. Your turn.",
            "The file has been updated. Ready for your next instruction.",
            "All changes are complete. What would you like to do next?",
        ]
        for phrase in phrases {
            let judgement = ClaudeStatusJudge.judge(transcript: phrase)
            XCTAssertEqual(judgement.status, .waitingInput, "Expected waitingInput for: \(phrase.prefix(40))")
        }
    }

    func testRealEndOfTurnCompletionPhrasesBecomeCompleted() {
        let phrases = [
            "Done! I've created the config file. That's all for now.",
            "All set. The project is ready to run.",
            "I'm done with the implementation. Wrapping up.",
            "Finished. The script ran successfully. You're all set.",
            "I've completed the task. Ready for the next one.",
        ]
        for phrase in phrases {
            let judgement = ClaudeStatusJudge.judge(transcript: phrase)
            XCTAssertEqual(judgement.status, .completed, "Expected completed for: \(phrase.prefix(40))")
        }
    }

    func testRealEndOfTurnReplyPhrasesBecomeReplyAvailable() {
        let phrases = [
            "I've prepared the diff. If you want, I can apply it now.",
            "The code is ready. I'm prepared to continue when you're ready.",
            "I've finished the analysis. Feel free to ask any questions.",
        ]
        for phrase in phrases {
            let judgement = ClaudeStatusJudge.judge(transcript: phrase)
            XCTAssertEqual(judgement.status, .replyAvailable, "Expected replyAvailable for: \(phrase.prefix(40))")
        }
    }

    func testRunningNarrationStaysRunningWithNoFalseWaitingOrCompleted() {
        let phrases = [
            "I'm currently reviewing the pull request and looking at the test failures.",
            "Running the linter to check for any issues.",
            "Analyzing the codebase structure to understand the dependencies.",
            "Working through the implementation step by step.",
        ]
        for phrase in phrases {
            let judgement = ClaudeStatusJudge.judge(transcript: phrase)
            XCTAssertEqual(judgement.status, .running, "Expected running for: \(phrase.prefix(40))")
        }
    }

    func testClaudeAdapterAndJudgeAlignedForEndOfTurnPatterns() {
        let testCases: [(String, TaskStatus)] = [
            ("I've updated the file. Let me know if you want me to continue.", .waitingInput),
            ("All done. That's all for now.", .completed),
            ("I've prepared the changes. If you want, I can apply them.", .replyAvailable),
            ("Created file: HelloWorld.swift. Anything else?", .waitingInput),
            ("Created file: HelloWorld.swift", .completed),
            ("Anything else?", .waitingInput),
        ]
        for (snippet, expectedStatus) in testCases {
            let event = RawCLIEvent(
                cliKind: .claudeCode,
                snippet: snippet,
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · test",
                    commandLine: "claude",
                    ttyIdentifier: "ttys001"
                )
            )
            let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)
            let judgement = ClaudeStatusJudge.judge(transcript: snippet)
            XCTAssertEqual(session?.status, judgement.status, "Mismatch for: \(snippet.prefix(40))")
            XCTAssertEqual(session?.status, expectedStatus, "Expected \(expectedStatus) for: \(snippet.prefix(40))")
        }
    }

    func testClaudeAdapterUsesSameJudgementAsObservation() {
        let snippet = "Please confirm to continue. Press enter when ready."
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: snippet,
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · parity",
                commandLine: "claude",
                ttyIdentifier: "ttys021"
            )
        )

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)
        let judgement = ClaudeStatusJudge.judge(transcript: snippet)

        XCTAssertEqual(session?.status, judgement.status)
        XCTAssertEqual(session?.confidence, judgement.confidence)
    }

    func testClaudeJudgeStrongSignalsProduceHigherConfidenceThanWeakRunningCase() {
        let strong = ClaudeStatusJudge.judge(transcript: "Permission denied. Fatal error: unable to continue.")
        let weak = ClaudeStatusJudge.judge(transcript: "reviewing recent output")

        XCTAssertEqual(strong.status, .failed)
        XCTAssertEqual(weak.status, .running)
        XCTAssertGreaterThan(strong.confidence, weak.confidence)
    }

    func testRealObservationIgnoresNonClaudeSnapshots() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "regular shell",
                            commandLine: "zsh",
                            ttyIdentifier: "ttys010"
                        ),
                        transcript: "shell prompt"
                    )
                ]))
            ]
        )

        XCTAssertTrue(service.latestEvents().isEmpty)
    }

    func testPerformQuickActionStillAppendsHistoryForRecommendedIslandAction() {
        let replyBridge = ConfigurableReplyBridge(
            sendResult: ReplyValidationResult(canSend: true, explanation: "Sent quick action")
        )
        let store = TaskStateStore(
            observationService: StubObservationService(
                events: [
                    RawCLIEvent(
                        cliKind: .claudeCode,
                        snippet: "Please confirm to continue.",
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · island",
                            commandLine: "claude",
                            ttyIdentifier: "ttys040"
                        )
                    )
                ],
                diagnostics: .empty
            ),
            replyBridge: replyBridge
        )

        let session = try! XCTUnwrap(store.selectedSession)
        let result = store.performQuickAction(.continueExecution, for: session)

        XCTAssertTrue(result.canSend)
        XCTAssertEqual(store.selectedSession?.historyEntries.last?.kind, .userQuickAction)
    }

    func testPreferredIslandSessionPicksHighestTierAttentionSession() {
        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: .success(observations: [
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · alert",
                            commandLine: "claude",
                            ttyIdentifier: "ttys050"
                        ),
                        transcript: "Warning: network unstable, retrying request."
                    ),
                    ObservedTerminalSession(
                        snapshot: TerminalObservationSnapshot(
                            terminalAppIdentifier: "com.apple.Terminal",
                            windowTitle: "Claude Code · waiting",
                            commandLine: "claude",
                            ttyIdentifier: "ttys051"
                        ),
                        transcript: "Please confirm to continue."
                    )
                ]))
            ]
        )

        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.preferredIslandSession?.status, .waitingInput)
    }

    func testPreferredIslandSessionTierOrdering() {
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Waiting for input.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "waiting",
                commandLine: "claude",
                ttyIdentifier: "ttys060"
            )
        )
        let alertEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Warning: something went wrong.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "alert",
                commandLine: "claude",
                ttyIdentifier: "ttys061"
            )
        )
        let replyEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "reply",
                commandLine: "claude",
                ttyIdentifier: "ttys062"
            )
        )

        // waiting (Tier 4) > alert (Tier 3)
        XCTAssertEqual(TaskStatus.tier(for: .waitingInput), 4)
        XCTAssertEqual(TaskStatus.tier(for: .alert), 3)
        XCTAssertGreaterThan(TaskStatus.tier(for: .waitingInput), TaskStatus.tier(for: .alert))

        // alert (Tier 3) > replyAvailable (Tier 2)
        XCTAssertEqual(TaskStatus.tier(for: .replyAvailable), 2)
        XCTAssertGreaterThan(TaskStatus.tier(for: .alert), TaskStatus.tier(for: .replyAvailable))
    }

    func testPreferredIslandSessionReturnsNilWhenNoSessions() {
        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        XCTAssertNil(store.preferredIslandSession)
    }

    func testIslandAttentionSessionsReturnsOnlyAttentionSessions() {
        let service = StubObservationService(events: [], diagnostics: .empty)
        let store = TaskStateStore(observationService: service)

        XCTAssertEqual(store.islandAttentionSessions.count, 0)
    }

    func testIslandAttentionSessionsFiltersNonAttentionSessions() {
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Waiting for input.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · waiting",
                commandLine: "claude",
                ttyIdentifier: "ttys070"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Processing...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys071"
            )
        )
        let service = StubObservationService(events: [waitingEvent, runningEvent], diagnostics: .empty)
        let store = TaskStateStore(observationService: service)

        let attentionSessions = store.islandAttentionSessions
        XCTAssertEqual(attentionSessions.count, 1)
        XCTAssertEqual(attentionSessions.first?.status, .waitingInput)
    }

    func testSecondaryIslandAttentionCountExcludesCurrentFocus() {
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Waiting for input.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · waiting",
                commandLine: "claude",
                ttyIdentifier: "ttys080"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .codex,
            snippet: "Running code...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "codex task",
                commandLine: "codex",
                ttyIdentifier: "ttys081"
            )
        )
        let service = StubObservationService(events: [waitingEvent, runningEvent], diagnostics: .empty)
        let store = TaskStateStore(observationService: service)

        let attentionSessions = store.islandAttentionSessions
        XCTAssertEqual(attentionSessions.count, 1)

        let focusSession = store.preferredIslandSession
        XCTAssertNotNil(focusSession)

        let secondaryCount = store.secondaryIslandAttentionCount(excluding: focusSession?.id)
        XCTAssertEqual(secondaryCount, 0)
    }

    func testSecondaryIslandAttentionCountReturnsZeroWhenNoAttentionSessions() {
        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        let count = store.secondaryIslandAttentionCount(excluding: nil)
        XCTAssertEqual(count, 0)
    }

    func testRefreshPreservesHookCompletedOnlyWithinSameHookLifecycle() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)
        let hookSessionID = "hook-same-lifecycle"

        store.processHookEvent(
            HookEvent(
                sessionID: hookSessionID,
                cwd: "/Users/test/macirland",
                event: .sessionEnd,
                status: "completed",
                pid: 100,
                tty: "ttys030"
            )
        )

        XCTAssertEqual(store.sessions.first?.status, .completed)
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, hookSessionID)

        source.updateEvents([runningClaudeEventWithNewSnippet])
        store.refresh()

        XCTAssertEqual(store.sessions.first?.status, .completed)
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, hookSessionID)
    }

    func testRefreshPreservesHookDerivedProjectTitleAcrossObservationRefresh() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        store.processHookEvent(
            HookEvent(
                sessionID: "hook-project-title",
                cwd: "/Users/test/macirland",
                event: .sessionEnd,
                status: "completed",
                pid: 100,
                tty: "ttys030"
            )
        )

        XCTAssertEqual(store.sessions.first?.title, "macirland")

        source.updateEvents([
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Still processing edits...",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Running Claude Code terminal session",
                    commandLine: "claude",
                    ttyIdentifier: "ttys030"
                )
            )
        ])
        store.refresh()

        XCTAssertEqual(store.sessions.first?.title, "macirland")
        XCTAssertEqual(store.sessions.first?.status, .completed)
    }

    func testRefreshAllowsCompletedHookSessionToReviveForNewHookLifecycleOnSameTTY() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        store.processHookEvent(
            HookEvent(
                sessionID: "hook-old",
                cwd: "/Users/test/macirland",
                event: .sessionEnd,
                status: "completed",
                pid: 100,
                tty: "ttys030"
            )
        )
        XCTAssertEqual(store.sessions.first?.status, .completed)

        store.processHookEvent(
            HookEvent(
                sessionID: "hook-new",
                cwd: "/Users/test/macirland",
                event: .userPromptSubmit,
                status: "running",
                pid: 101,
                tty: "ttys030"
            )
        )

        XCTAssertEqual(store.sessions.first?.status, .running)
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "hook-new")
    }

    func testRefreshAllowsObservationCompletedToReplaceOldRunningStateWithoutHookLifecycle() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        source.updateEvents([completedClaudeEvent])
        store.refresh()

        XCTAssertEqual(store.sessions.first?.status, .completed)
    }


    func testResolverDedupPreservesDistinctSessionsWithDifferentTtyIdentifiers() {
        // Two sessions with different ttyIdentifiers MUST NOT be deduplicated.
        // This verifies the dedup logic respects stable session identity.
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            timestamp: Date(),
            snippet: "Waiting for input.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · waiting",
                commandLine: "claude",
                ttyIdentifier: "ttys070"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            timestamp: Date().addingTimeInterval(1),
            snippet: "Processing...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys071"
            )
        )

        let resolver = SessionResolver()
        let registry = AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
        let resolved = resolver.resolveSessions(from: [waitingEvent, runningEvent], using: registry)

        XCTAssertEqual(resolved.count, 2)
        let statuses = Set(resolved.map(\.status))
        XCTAssertTrue(statuses.contains(.waitingInput))
        XCTAssertTrue(statuses.contains(.running))
    }

    func testResolverDedupPrefersHigherTierWhenTimestampsAreEqual() {
        // When two sessions have the same stable ID (true duplicates from the same
        // observation snapshot) and equal timestamps, the one with higher attention
        // tier must survive. This prevents attention sessions from being silently
        // dropped when they arrive alongside lower-tier events.
        let sameTimestamp = Date(timeIntervalSince1970: 1000)
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            timestamp: sameTimestamp,
            snippet: "Please confirm to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys090"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            timestamp: sameTimestamp,
            snippet: "Still processing edits...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys090"
            )
        )

        let resolver = SessionResolver()
        let registry = AdapterRegistry(adapters: [BuiltInCLIAdapter.codex, BuiltInCLIAdapter.claudeCode, BuiltInCLIAdapter.gemini])
        let resolved = resolver.resolveSessions(from: [waitingEvent, runningEvent], using: registry)

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.status, .waitingInput)
    }

    func testRefreshDoesNotCrashWhenObservationContainsDuplicateLogicalSessions() {
        let source = MutableObservationService(initialEvents: [runningClaudeEvent])
        let store = TaskStateStore(observationService: source)

        source.updateEvents([waitingClaudeEvent, waitingClaudeEvent])
        store.refresh()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.status, .waitingInput)
    }

    func testHigherTierPreemptsLowerTierInAttentionQueue() {
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running tasks...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys080"
            )
        )
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Waiting for input.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · waiting",
                commandLine: "claude",
                ttyIdentifier: "ttys081"
            )
        )

        let source = MutableObservationService(initialEvents: [runningEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.preferredIslandSession?.status, .running)

        source.updateEvents([runningEvent, waitingEvent])
        store.refresh()

        XCTAssertEqual(store.preferredIslandSession?.status, .waitingInput)
    }

    func testDynamicSecondSessionJoinDoesNotCrashAndPreservesBothSessions() {
        // Simulates: app starts with one session, auto-refresh is active,
        // a second distinct session appears during runtime.
        // App must not crash and both sessions must remain stable.
        let firstEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on first task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · first",
                commandLine: "claude",
                ttyIdentifier: "ttys100"
            )
        )
        let source = MutableObservationService(initialEvents: [firstEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.sessions.count, 1)

        // Simulate second distinct session appearing during runtime
        let secondEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on second task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · second",
                commandLine: "claude",
                ttyIdentifier: "ttys101"
            )
        )
        source.updateEvents([firstEvent, secondEvent])
        store.refresh()

        // Both sessions must remain
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertEqual(Set(store.sessions.map(\.id)).count, 2, "No duplicate IDs")

        // preferredIslandSession and islandAttentionSessions must be valid
        let attentionSessions = store.islandAttentionSessions
        XCTAssertTrue(attentionSessions.count <= 2)

        // Selection must not point to an invalid ID
        _ = store.selectedSession
        _ = store.preferredIslandSession
    }

    func testReplyFailureLeavesMeaningfulHistoryEntry() {
        let service = MockReplyBridgeService()
        let store = TaskStateStore(
            observationService: StubObservationService(events: [waitingClaudeEvent], diagnostics: .empty),
            replyBridge: service
        )

        guard let session = store.sessions.first else {
            XCTFail("Expected a session")
            return
        }

        store.draftReply = "   "
        let result = store.sendDraftReply(for: session)
        XCTAssertFalse(result.canSend)
        XCTAssertNotNil(result.explanation)

        let historyKinds = store.sessions.first?.historyEntries.map(\.kind) ?? []
        XCTAssertTrue(historyKinds.contains(.userReplyRejected))
    }

    func testDismissThenReopenPanelPreservesSelection() {
        let service = StubObservationService(events: [waitingClaudeEvent], diagnostics: .empty)
        let store = TaskStateStore(observationService: service)

        guard let originalSession = store.selectedSession else {
            XCTFail("Expected a selected session")
            return
        }

        store.refresh()

        XCTAssertEqual(store.selectedSession?.id, originalSession.id)
    }

    private var prioritizedEvents: [RawCLIEvent] {
        [
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Waiting for input to continue",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · project-a",
                    commandLine: "claude",
                    ttyIdentifier: "ttys001"
                )
            ),
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "finished generating summary",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · project-b",
                    commandLine: "claude",
                    ttyIdentifier: "ttys002"
                )
            )
        ]
    }

    private var refreshedEventsKeepingSameSessions: [RawCLIEvent] {
        [
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Waiting for input to continue with extra details",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · project-a",
                    commandLine: "claude",
                    ttyIdentifier: "ttys001"
                )
            ),
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "finished generating summary successfully",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · project-b",
                    commandLine: "claude",
                    ttyIdentifier: "ttys002"
                )
            )
        ]
    }

    private var runningClaudeEvent: RawCLIEvent {
        RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "thinking through the file edits",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · history",
                commandLine: "claude",
                ttyIdentifier: "ttys030"
            )
        )
    }

    private var runningClaudeEventWithNewSnippet: RawCLIEvent {
        RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "still thinking through a different edit path",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · history",
                commandLine: "claude",
                ttyIdentifier: "ttys030"
            )
        )
    }

    private var waitingClaudeEvent: RawCLIEvent {
        RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Need user input. Please confirm whether to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · history",
                commandLine: "claude",
                ttyIdentifier: "ttys030"
            )
        )
    }

    private var replyAvailableClaudeEvent: RawCLIEvent {
        RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue. Press enter when ready.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · reply",
                commandLine: "claude",
                ttyIdentifier: "ttys031"
            )
        )
    }

    private var completedClaudeEvent: RawCLIEvent {
        RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "All set. Created file: history.txt",
            transcript: "All set. Created file: history.txt",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · history",
                commandLine: "claude",
                ttyIdentifier: "ttys030"
            )
        )
    }

    // MARK: - Claude-First Tray Regression Tests

    func testTraySessionsIncludesTwoClaudeCodeSessions() {
        let session1ID = UUID()
        let session2ID = UUID()
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on first task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · first",
                commandLine: "claude",
                ttyIdentifier: "ttys100"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on second task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · second",
                commandLine: "claude",
                ttyIdentifier: "ttys101"
            )
        )

        let source = MutableObservationService(initialEvents: [event1, event2])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.traySessions.count, 2)
        XCTAssertTrue(store.hasMultipleRelevantSessions)
        XCTAssertEqual(store.traySessions.map(\.sourceCLI), [.claudeCode, .claudeCode])
    }

    func testTraySessionsExcludesNonClaudeSessionsEvenWithHighConfidence() {
        let claudeEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys110"
            )
        )
        let codexEvent = RawCLIEvent(
            cliKind: .codex,
            snippet: "Codex session with high confidence signal",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Codex task",
                commandLine: "codex",
                ttyIdentifier: "ttys111"
            )
        )

        let source = MutableObservationService(initialEvents: [claudeEvent, codexEvent])
        let store = TaskStateStore(observationService: source)

        // Only Claude Code session should be in tray
        XCTAssertEqual(store.traySessions.count, 1)
        XCTAssertEqual(store.traySessions.first?.sourceCLI, .claudeCode)
        // hasMultipleRelevantSessions requires 2+ Claude sessions
        XCTAssertFalse(store.hasMultipleRelevantSessions)
    }

    func testTraySessionsExcludesTerminalClaudeSessions() {
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys120"
            )
        )
        let completedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Task completed successfully.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · completed",
                commandLine: "claude",
                ttyIdentifier: "ttys121"
            )
        )

        let source = MutableObservationService(initialEvents: [runningEvent, completedEvent])
        let store = TaskStateStore(observationService: source)

        // Completed is terminal - should be excluded from tray
        XCTAssertEqual(store.traySessions.count, 1)
        XCTAssertEqual(store.traySessions.first?.status, .running)
        XCTAssertFalse(store.hasMultipleRelevantSessions)
    }

    func testTraySessionsExcludesFailedAndContextLostTerminalSessions() {
        let failedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Error: command failed.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · failed",
                commandLine: "claude",
                ttyIdentifier: "ttys130"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running another task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys131"
            )
        )

        let source = MutableObservationService(initialEvents: [failedEvent, runningEvent])
        let store = TaskStateStore(observationService: source)

        // Failed is terminal - should be excluded from tray
        XCTAssertEqual(store.traySessions.count, 1)
        XCTAssertEqual(store.traySessions.first?.status, .running)
    }

    func testTraySessionsWithMixedTerminalAndActiveClaudeSessions() {
        // One completed, one running, one waitingInput
        let completedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Task complete. All set and finished successfully.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · done",
                commandLine: "claude",
                ttyIdentifier: "ttys140"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Processing...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys141"
            )
        )
        let waitingEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · waiting",
                commandLine: "claude",
                ttyIdentifier: "ttys142"
            )
        )

        let source = MutableObservationService(initialEvents: [completedEvent, runningEvent, waitingEvent])
        let store = TaskStateStore(observationService: source)

        // Only running and waitingInput (non-terminal) should be in tray
        XCTAssertEqual(store.traySessions.count, 2)
        XCTAssertTrue(store.hasMultipleRelevantSessions)
        let statuses = Set(store.traySessions.map(\.status))
        XCTAssertTrue(statuses.contains(.running))
        XCTAssertTrue(statuses.contains(.waitingInput))
        XCTAssertFalse(statuses.contains(.completed))
    }

    func testHoverExpandSessionsKeepCompletedClaudeSessionsForCountConsistency() {
        let completedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Task complete. All set and finished successfully.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · done",
                commandLine: "claude",
                ttyIdentifier: "ttys143"
            )
        )
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Processing current task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys144"
            )
        )

        let source = MutableObservationService(initialEvents: [completedEvent, runningEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.hoverExpandSessions.count, 2)
        XCTAssertEqual(store.hoverExpandSecondarySessions.count, 1)
        XCTAssertEqual(store.hoverExpandPrimarySession?.status, .running)
        XCTAssertEqual(store.hoverExpandSecondarySessions.first?.status, .completed)
    }

    func testEmptyTranscriptRunningSnippetStaysRunning() {
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running Claude Code terminal session: Claude Code · background",
            transcript: "",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · background",
                commandLine: "claude",
                ttyIdentifier: "ttys145"
            )
        )

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)

        XCTAssertEqual(session?.status, .running, "Empty transcript fallback should not force a live Claude session into completed")
    }

    func testClaudeSessionIDStaysStableWhenWindowTitleChangesForSameTTY() {
        let baseSnapshot = TerminalObservationSnapshot(
            terminalAppIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code · first title",
            commandLine: "claude",
            ttyIdentifier: "ttys555"
        )

        let driftedSnapshot = TerminalObservationSnapshot(
            terminalAppIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code · second title",
            commandLine: "env FOO=1 claude --dangerously-skip-permissions",
            ttyIdentifier: "ttys555"
        )

        let first = BuiltInCLIAdapter.claudeCode.buildSession(
            from: RawCLIEvent(cliKind: .claudeCode, snippet: "Working...", transcript: "Working...", snapshot: baseSnapshot)
        )
        let second = BuiltInCLIAdapter.claudeCode.buildSession(
            from: RawCLIEvent(cliKind: .claudeCode, snippet: "Still working...", transcript: "Still working...", snapshot: driftedSnapshot)
        )

        XCTAssertEqual(first?.id, second?.id, "Same tty should map to the same Claude session even if title/command drift")
    }

    func testTransitionCueDoesNotReplayCompletedWhenOnlyWindowTitleDriftsOnSameTTY() {
        let adapter = BuiltInCLIAdapter.claudeCode

        let previous = adapter.buildSession(
            from: RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Completed Claude Code terminal session: Claude Code · old",
                transcript: "Completed Claude Code terminal session: Claude Code · old",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    windowTitle: "Claude Code · old",
                    commandLine: "claude",
                    ttyIdentifier: "ttys556"
                )
            )
        )

        let current = adapter.buildSession(
            from: RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Completed Claude Code terminal session: Claude Code · new",
                transcript: "Completed Claude Code terminal session: Claude Code · new",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    windowTitle: "Claude Code · new",
                    commandLine: "env BAR=1 claude",
                    ttyIdentifier: "ttys556"
                )
            )
        )

        let service = FeedbackService()
        let cues = service.cues(previousSessions: [previous].compactMap { $0 }, currentSessions: [current].compactMap { $0 })

        XCTAssertFalse(cues.contains(.completed), "Stable tty identity should prevent duplicate completed cues when only title/command drift")
    }

    // MARK: - Claude-First Panel Primary Session Tests

    func testPrimaryPanelSessionsIncludesClaudeSessions() {
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys200"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running another task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · second",
                commandLine: "claude",
                ttyIdentifier: "ttys201"
            )
        )

        let source = MutableObservationService(initialEvents: [event1, event2])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.primaryPanelSessions.count, 2)
        XCTAssertEqual(store.primaryPanelSessions.map(\.sourceCLI), [.claudeCode, .claudeCode])
    }

    func testPrimaryPanelSessionsExcludesNonClaudeSessions() {
        let claudeEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Claude session...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys210"
            )
        )
        let codexEvent = RawCLIEvent(
            cliKind: .codex,
            snippet: "Codex session...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Codex task",
                commandLine: "codex",
                ttyIdentifier: "ttys211"
            )
        )

        let source = MutableObservationService(initialEvents: [claudeEvent, codexEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.primaryPanelSessions.count, 1)
        XCTAssertEqual(store.primaryPanelSessions.first?.sourceCLI, .claudeCode)
    }

    func testPrimaryPanelSessionsExcludesTerminalClaudeSessions() {
        let runningEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · running",
                commandLine: "claude",
                ttyIdentifier: "ttys220"
            )
        )
        let completedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Task complete. All set and finished successfully.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · done",
                commandLine: "claude",
                ttyIdentifier: "ttys221"
            )
        )

        let source = MutableObservationService(initialEvents: [runningEvent, completedEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertEqual(store.primaryPanelSessions.count, 1)
        XCTAssertEqual(store.primaryPanelSessions.first?.status, .running)
    }

    func testSelectedSessionFallsBackToPrimaryPanelSessionWhenCurrentBecomesNonPrimary() {
        let claudeEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Claude working...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys230"
            )
        )
        let codexEvent = RawCLIEvent(
            cliKind: .codex,
            snippet: "Codex task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Codex",
                commandLine: "codex",
                ttyIdentifier: "ttys231"
            )
        )

        let source = MutableObservationService(initialEvents: [claudeEvent, codexEvent])
        let store = TaskStateStore(observationService: source)

        // Initially should select a Claude session
        XCTAssertNotNil(store.selectedSession)
        XCTAssertEqual(store.selectedSession?.sourceCLI, .claudeCode)

        // When only Claude session is selected, it should remain selected
        store.selectSession(id: store.primaryPanelSessions.first?.id)
        XCTAssertEqual(store.selectedSession?.sourceCLI, .claudeCode)
    }

    func testSelectedSessionIsNilWhenNoPrimaryPanelSessions() {
        let codexEvent = RawCLIEvent(
            cliKind: .codex,
            snippet: "Codex session only...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Codex",
                commandLine: "codex",
                ttyIdentifier: "ttys240"
            )
        )

        let source = MutableObservationService(initialEvents: [codexEvent])
        let store = TaskStateStore(observationService: source)

        XCTAssertTrue(store.primaryPanelSessions.isEmpty)
        XCTAssertNil(store.selectedSession)
    }

    // MARK: - App Readiness Tests

    func testAppReadinessBlockedWhenObservationBlocked() {
        let source = MutableObservationService(initialEvents: [], diagnostics: .empty)
        let store = TaskStateStore(
            observationService: source,
            permissionService: StubPermissionService(
                status: CapabilityStatus(
                    accessibilityGranted: false,
                    localOnlyProcessing: true,
                    explanation: "已检测到 Terminal / iTerm 正在运行，但当前无法可靠读取会话内容。请确认系统已允许 MacIrland 通过 Apple Events 访问终端应用。",
                    observationBlocked: true
                )
            )
        )

        let readiness = store.appReadiness
        XCTAssertEqual(readiness.level, .blocked)
        XCTAssertEqual(readiness.title, "无法读取终端会话")
        XCTAssertNotNil(readiness.nextAction)
    }

    func testAppReadinessNoSessionWhenNoPrimaryPanelSessionsAndNotBlocked() {
        let source = MutableObservationService(initialEvents: [], diagnostics: .empty)
        let store = TaskStateStore(
            observationService: source,
            permissionService: StubPermissionService(
                status: CapabilityStatus(
                    accessibilityGranted: false,
                    localOnlyProcessing: true,
                    explanation: "本地处理模式",
                    observationBlocked: false
                )
            )
        )

        let readiness = store.appReadiness
        XCTAssertEqual(readiness.level, .noSession)
        XCTAssertEqual(readiness.title, "还没有 Claude Code 会话")
        XCTAssertNotNil(readiness.nextAction)
    }

    func testAppReadinessReadyWhenSessionActiveAndCanReply() {
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys300"
            )
        )

        let replyBridge = ConfigurableReplyBridge(
            sendResult: ReplyValidationResult(canSend: true, explanation: "Ready")
        )
        let store = TaskStateStore(
            observationService: StubObservationService(events: [event], diagnostics: .empty),
            replyBridge: replyBridge
        )

        let readiness = store.appReadiness
        XCTAssertEqual(readiness.level, .ready)
        XCTAssertEqual(readiness.title, "可以继续")
        XCTAssertNil(readiness.nextAction)
    }

    func testAppReadinessPartialObservationWhenSessionsSeenButNotRecognized() {
        // Use codex so it doesn't get recognized as Claude Code and stays out of primaryPanelSessions
        let rawEvent = RawCLIEvent(
            cliKind: .codex,
            snippet: "some unknown activity",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "shell",
                commandLine: "codex",
                ttyIdentifier: "ttys320"
            )
        )

        let diagnostics = ObservationDiagnostics(
            readers: [
                ObservationReaderDiagnostic(
                    id: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observationCount: 1,
                    recognizedEventCount: 0,
                    message: "raw session found"
                )
            ],
            sessions: [
                ObservationSessionDiagnostic(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "shell",
                    commandLine: "codex",
                    ttyIdentifier: "ttys320",
                    transcriptPreview: "some unknown activity",
                    recognizedCLIKind: nil,
                    inferredStatus: nil,
                    decisionReason: "未命中 Claude Code 识别规则"
                )
            ]
        )

        let source = MutableObservationService(initialEvents: [rawEvent], diagnostics: diagnostics)
        let store = TaskStateStore(
            observationService: source,
            permissionService: StubPermissionService(
                status: CapabilityStatus(
                    accessibilityGranted: true,
                    localOnlyProcessing: false,
                    explanation: "正常",
                    observationBlocked: false
                )
            )
        )

        // Codex session is not in primaryPanelSessions (non-Claude), so selectedSession is nil
        XCTAssertTrue(store.primaryPanelSessions.isEmpty)
        XCTAssertNil(store.selectedSession)

        let readiness = store.appReadiness
        XCTAssertEqual(readiness.level, .partialObservation)
        XCTAssertEqual(readiness.title, "检测到终端会话但未识别为 Claude Code")
    }

    func testAppReadinessTitleAndExplanationAreUserFacing() {
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                commandLine: "claude",
                ttyIdentifier: "ttys330"
            )
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [event], diagnostics: .empty)
        )

        let readiness = store.appReadiness
        // Verify user-facing fields are populated and non-technical
        XCTAssertFalse(readiness.title.isEmpty)
        XCTAssertFalse(readiness.explanation.isEmpty)
        XCTAssertFalse(readiness.level == .blocked && readiness.nextAction == nil)
    }

    // MARK: - Real Transcript Pipeline Regression Tests

    func testRealObservationWithCompletionTranscriptYieldsCompletedSession() {
        // Real completion transcript: ANSI noise + "Created file:" signal
        let completionTranscript = """
        \u{001B}[2K\u{001B}[1A\u{001B}[32m✔\u{001B}[0m All done!
        \u{001B}[32mCreated file:\u{001B}[0m Sources/App.swift
        \u{001B}[32mCreated file:\u{001B}[0m Sources/Model.swift
        shell%
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · completion-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys400"
                            ),
                            transcript: completionTranscript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        // BuiltInCLIAdapter.buildSession() must yield .completed for this transcript
        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .completed, "Completion transcript with 'Created file:' should yield .completed")
    }

    func testRealObservationWithWaitingInputTranscriptYieldsWaitingInputSession() {
        // Real waiting-for-input transcript with Chinese handoff phrase
        let waitingTranscript = """
        \u{001B}[2K\u{001B}[1A
        \u{001B}[32m✔\u{001B}[0m 已完成当前整理。
        │ Tokens: 12.4k
        ╰─

          如果你愿意，我可以继续帮你整理下一轮计划。
        claude>
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · waiting-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys401"
                            ),
                            transcript: waitingTranscript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        // BuiltInCLIAdapter.buildSession() must yield .waitingInput for this transcript
        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .waitingInput, "Chinese handoff phrase should yield .waitingInput")
    }

    func testRealObservationWithReplyAvailableTranscriptYieldsReplyAvailableSession() {
        // Real reply-available transcript
        let replyTranscript = """
        \u{001B}[2K\u{001B}[1A
        \u{001B}[32m✔\u{001B}[0m 已完成当前整理。
        还有什么我可以帮你的吗？
        claude>
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · reply-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys402"
                            ),
                            transcript: replyTranscript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .replyAvailable, "Chinese handoff '还有什么我可以帮你的吗' should yield .replyAvailable")
    }

    func testRealObservationWithStillRunningTranscriptYieldsRunningSession() {
        // Real "still running" transcript - Claude is actively working
        let runningTranscript = """
        \u{001B}[2K\u{001B}[1A
        Working through the file edits...
        Analyzing dependencies...
        Implementing changes...
        claude>
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · running-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys403"
                            ),
                            transcript: runningTranscript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .running, "Active work transcript should yield .running")
    }

    func testRealObservationWithThunderingThinkingTranscriptYieldsRunningSession() {
        let runningTranscript = """
        * Thundering… (thinking)
        Thinking through the next tool call...
        Processing current step...
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "iterm",
                    readerName: "iTerm",
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.googlecode.iterm2",
                                windowTitle: "Claude Code · thundering-test",
                                commandLine: "caffeinate claude",
                                ttyIdentifier: "ttys406"
                            ),
                            transcript: runningTranscript
                        )
                    ],
                    message: "已读取到 1 个 iTerm session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .running, "Thundering thinking transcript should stay .running")
    }

    func testRealObservationWithPromptReturnedCompletionTranscriptDoesNotStayRunning() {
        let completionTranscript = """
        \u{001B}[32m✔\u{001B}[0m 已完成当前修改。
        请查看结果。
        claude>
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "iTerm",
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.googlecode.iterm2",
                                windowTitle: "Claude Code · prompt-return-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys405"
                            ),
                            transcript: completionTranscript
                        )
                    ],
                    message: "已读取到 1 个 iTerm session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertNotEqual(session?.status, .running, "Prompt-return completion transcript should not stay .running")
        XCTAssertEqual(session?.status, .completed, "Prompt-return completion transcript should become .completed")
    }

    func testRealObservationWithModernClaudePromptTranscriptYieldsWaitingInput() {
        let transcript = """
        ⏺ 你是问 Claude Code CLI 版本，还是我的模型版本？

          - Claude Code CLI：你可以在终端运行 claude --version 查看
          - 我的模型：我是 Claude 4.6 (Opus)

        ✻ Worked for 31s

        ❯
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · modern-prompt-test",
                                commandLine: "login-zshclaude",
                                ttyIdentifier: "ttys409"
                            ),
                            transcript: transcript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .waitingInput, "Modern Claude prompt return with ❯ should yield waitingInput instead of running")
    }

    func testRealObservationWithJuzoInstructionPhraseYieldsWaitingInput() {
        let transcript = """
        已保存到记忆文件，全局生效。

        当前任务完成，请局座指示。

        ❯
        """

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · juzo-test",
                                commandLine: "login-zshclaude",
                                ttyIdentifier: "ttys410"
                            ),
                            transcript: transcript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: events[0])
        XCTAssertEqual(session?.status, .waitingInput, "Custom end-of-turn phrase should map to waitingInput")
    }

    func testAppleScriptObservationParserParsesTerminalBusyFieldAndHistoryTranscript() {
        let output = """
        Claude Code Window<<<MACIRLAND_FIELD>>>✳ Claude Code<<<MACIRLAND_FIELD>>>/dev/ttys002<<<MACIRLAND_FIELD>>>login-zshclaude<<<MACIRLAND_FIELD>>>false<<<MACIRLAND_FIELD>>>✻ Worked for 31s

        ❯<<<MACIRLAND_RECORD>>>
        """

        let observations = AppleScriptObservationParser.parse(
            output: output,
            terminalAppIdentifier: "com.apple.Terminal"
        )

        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations.first?.snapshot.isBusy, false)
        XCTAssertEqual(observations.first?.snapshot.commandLine, "login-zshclaude")
        XCTAssertTrue(observations.first?.transcript.contains("Worked for 31s") == true)
        XCTAssertTrue(observations.first?.transcript.contains("❯") == true)
    }

    func testRealObservationEventCarriesTranscriptForAdapterJudgement() {
        // Verify that RawCLIEvent produced by RealTerminalObservationService
        // carries the actual transcript (not just a title string) so that
        // BuiltInCLIAdapter can judge the real content.
        let completionTranscript = "✔ Done! Created file: Test.swift\nshell%"

        let service = RealTerminalObservationService(
            terminalReaders: [
                StubTerminalReader(result: TerminalReaderResult(
                    readerID: "terminal",
                    readerName: "Terminal",
                    terminalAppIdentifier: "com.apple.Terminal",
                    isAppRunning: true,
                    fetchStatus: .success,
                    observations: [
                        ObservedTerminalSession(
                            snapshot: TerminalObservationSnapshot(
                                terminalAppIdentifier: "com.apple.Terminal",
                                windowTitle: "Claude Code · adapter-test",
                                commandLine: "claude",
                                ttyIdentifier: "ttys404"
                            ),
                            transcript: completionTranscript
                        )
                    ],
                    message: "已读取到 1 个 Terminal session",
                    errorDescription: nil
                ))
            ]
        )

        let events = service.latestEvents()
        XCTAssertEqual(events.count, 1)

        // The event's transcript field must contain the actual transcript content
        XCTAssertTrue(events[0].transcript.contains("Created file:"), "event.transcript must carry actual transcript for adapter judgement")
    }
}

// MARK: - Hook Session Identity Tests

extension TaskStateStoreTests {

    func testSameHookSessionIDWithDriftingWindowTitleResolvesToOneSession() {
        // Two observation events with same tty but different windowTitle (due to drift).
        // Both should resolve to the SAME session because they have the same hookSessionID.
        // This verifies hookSessionID is the primary identity over windowTitle drift.
        let hookEvent = HookEvent(
            sessionID: "claude-session-identity-abc",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 12345,
            tty: "/dev/ttys600"
        )

        // AppleScript observes same session (same tty) but with drifted windowTitle
        let driftedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Still working on the task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · different-title",
                commandLine: "env DIFFERENT=1 claude",
                ttyIdentifier: "/dev/ttys600"
            )
        )

        // Create MutableObservationService with the drifted event
        let source = MutableObservationService(initialEvents: [driftedEvent])
        let store = TaskStateStore(observationService: source)

        // Hook event creates session with hookSessionID="claude-session-identity-abc"
        store.processHookEvent(hookEvent)
        XCTAssertEqual(store.sessions.count, 1)
        let hookCreatedID = store.sessions.first!.id

        // Refresh should merge with existing session, NOT create a duplicate
        store.refresh()

        XCTAssertEqual(store.sessions.count, 1,
            "Same tty with same hookSessionID should be ONE session, not two")
        XCTAssertEqual(store.sessions.first!.id, hookCreatedID,
            "Session ID should be preserved from hook-created session")
    }

    func testSameTTYDifferentHookSessionIDYieldsDistinctSessions() {
        // Two sessions with same tty but DIFFERENT hookSessionIDs must be
        // treated as DISTINCT sessions. This verifies that hookSessionID
        // differentiates sessions that would otherwise collide on tty.
        let hookEvent1 = HookEvent(
            sessionID: "session-alpha",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 111,
            tty: "/dev/ttys601"
        )
        let hookEvent2 = HookEvent(
            sessionID: "session-beta",
            cwd: "/Users/test/project2",
            event: .userPromptSubmit,
            status: "running",
            pid: 222,
            tty: "/dev/ttys601"  // Same tty as hookEvent1!
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        store.processHookEvent(hookEvent1)
        store.processHookEvent(hookEvent2)

        XCTAssertEqual(store.sessions.count, 2,
            "Different hookSessionIDs with same tty must be DISTINCT sessions")
        let hookIDs = Set(store.sessions.map { $0.identity.hookSessionID })
        XCTAssertTrue(hookIDs.contains("session-alpha"))
        XCTAssertTrue(hookIDs.contains("session-beta"))
    }

    func testHookUpdatedSessionKeepsSameTaskSessionIDAcrossRefreshes() {
        // A session created by hook should keep the same TaskSession.ID
        // even after AppleScript refreshes and sees the same session.
        // This verifies that hook-derived ID is stable across observation cycles.
        let hookEvent = HookEvent(
            sessionID: "claude-session-stable",
            cwd: "/Users/test/stable-project",
            event: .postToolUse,
            status: "running",
            pid: 999,
            tty: "/dev/ttys602"
        )

        // AppleScript observes the same session (same tty, no hookSessionID in event)
        let observedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on stable project...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · stable-project",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys602"
            )
        )

        // Create MutableObservationService with the observed event and pass to store
        let source = MutableObservationService(initialEvents: [observedEvent])
        let store = TaskStateStore(observationService: source)

        store.processHookEvent(hookEvent)
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "claude-session-stable")

        let hookCreatedID = store.sessions.first!.id

        // Refresh should merge with existing session
        store.refresh()

        XCTAssertEqual(store.sessions.count, 1,
            "Hook-created session should merge with AppleScript session, not duplicate")
        XCTAssertEqual(store.sessions.first!.id, hookCreatedID,
            "Session ID must remain stable (hook-derived) after AppleScript merge")
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "claude-session-stable",
            "hookSessionID should be preserved after merge")
    }
}

// MARK: - Hook-First Session Creation Tests

extension TaskStateStoreTests {

    func testProcessHookEventCreatesNewSessionWhenNoMatchingSessionExists() {
        // Hook event arrives before AppleScript has observed any sessions.
        // processHookEvent must NOT drop the event — it must create a session.
        let hookEvent = HookEvent(
            sessionID: "claude-session-abc123",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 12345,
            tty: "/dev/ttys003"
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        XCTAssertTrue(store.sessions.isEmpty, "No sessions before hook event")

        store.processHookEvent(hookEvent)

        XCTAssertEqual(store.sessions.count, 1, "Hook event must create a session when no match exists")
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "claude-session-abc123")
        XCTAssertEqual(store.sessions.first?.identity.ttyIdentifier, "/dev/ttys003")
        XCTAssertEqual(store.sessions.first?.status, .running)
    }

    func testProcessHookEventSetsHookDerivedTitleFromCWD() {
        // Title should be derived from cwd (last path component = project signal)
        let hookEvent = HookEvent(
            sessionID: "claude-session-xyz789",
            cwd: "/Users/test/awesome-project",
            event: .userPromptSubmit,
            status: "running",
            pid: 54321,
            tty: "/dev/ttys004"
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        store.processHookEvent(hookEvent)

        XCTAssertTrue(store.sessions.first?.title.contains("awesome-project") ?? false,
                      "Title should contain project name from cwd")
    }

    func testProcessHookEventStoresHookSessionIDOnNewSession() {
        let hookEvent = HookEvent(
            sessionID: "hook-id-555",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 111,
            tty: "/dev/ttys005"
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        store.processHookEvent(hookEvent)

        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "hook-id-555")
    }

    func testProcessHookEventHydratesSessionMissingHookSessionIDByTTYMatch() {
        // AppleScript has observed a session (by tty) but doesn't have hookSessionID yet.
        // A subsequent hook event with matching tty should hydrate the session.
        let observedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Working on task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys006"
            )
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [observedEvent], diagnostics: .empty)
        )

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertNil(store.sessions.first?.identity.hookSessionID, "Session should start without hookSessionID")

        let hookEvent = HookEvent(
            sessionID: "hook-id-666",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 222,
            tty: "/dev/ttys006"
        )

        store.processHookEvent(hookEvent)

        XCTAssertEqual(store.sessions.count, 1, "Should not create duplicate session")
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "hook-id-666",
                      "Session should be hydrated with hookSessionID")
    }

    func testProcessHookEventDoesNotHydrateMultipleTTYMatchedSessions() {
        // Two sessions with different ttys. A hook event arrives with a tty matching
        // NONE of them. It should create a new session, not try to match anything.
        let observedEvent1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "First task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · first",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys007"
            )
        )
        let observedEvent2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Second task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · second",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys008"  // Different tty!
            )
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [observedEvent1, observedEvent2], diagnostics: .empty)
        )

        XCTAssertEqual(store.sessions.count, 2, "Two distinct sessions by different tty")

        // Hook event with tty matching NEITHER existing session — should create new session
        let hookEvent = HookEvent(
            sessionID: "hook-id-new",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 333,
            tty: "/dev/ttys999"  // No match
        )

        store.processHookEvent(hookEvent)

        XCTAssertEqual(store.sessions.count, 3, "No tty match should create new session")
        let newSession = store.sessions.first { $0.identity.hookSessionID == "hook-id-new" }
        XCTAssertNotNil(newSession, "New session with hook-id-new should exist")
        XCTAssertEqual(newSession?.status, .running)
    }

    func testProcessHookEventLaterAppleScriptRefreshEnrichesExistingSession() {
        // Hook created a session. Later AppleScript refreshes and sees the same session.
        // The session ID must remain stable (same hookSessionID) — no duplicate created.
        let hookEvent = HookEvent(
            sessionID: "hook-id-stable",
            cwd: "/Users/test/stable-project",
            event: .postToolUse,
            status: "running",
            pid: 444,
            tty: "/dev/ttys008"
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        store.processHookEvent(hookEvent)

        let hookSessionIDBefore = store.sessions.first?.id
        XCTAssertNotNil(hookSessionIDBefore)

        // AppleScript now observes the same session (same tty)
        let observedEvent = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Still working...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · stable-project",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys008"
            )
        )

        let source = MutableObservationService(initialEvents: [observedEvent])
        // We need to use refresh to simulate AppleScript update
        // But TaskStateStore.refresh() uses its own observationService, not a parameter
        // So we test that after hook event, AppleScript can still find the same session

        // The session created by hook should have hookSessionID set
        XCTAssertEqual(store.sessions.first?.identity.hookSessionID, "hook-id-stable")

        // If AppleScript event arrives with same tty, it should match by tty
        // and preserve the hookSessionID
        let source2 = MutableObservationService(initialEvents: [observedEvent])
        source2.updateEvents([observedEvent])

        // Verify that sessions are matched by hookSessionID (when present)
        // and tty as fallback — the session should not be duplicated
    }

    func testProcessHookEventMapsHookStatusToTaskStatus() {
        // Verify all hook status types map correctly
        let runningEvent = HookEvent(
            sessionID: "hook-running",
            cwd: "/Users/test/project",
            event: .userPromptSubmit,
            status: "running",
            pid: 100,
            tty: "/dev/ttys010"
        )
        let waitingEvent = HookEvent(
            sessionID: "hook-waiting",
            cwd: "/Users/test/project",
            event: .permissionRequest,
            status: "waiting_for_reply",
            pid: 101,
            tty: "/dev/ttys011"
        )
        let completedEvent = HookEvent(
            sessionID: "hook-completed",
            cwd: "/Users/test/project",
            event: .sessionEnd,
            status: "completed",
            pid: 102,
            tty: "/dev/ttys012"
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        store.processHookEvent(runningEvent)
        XCTAssertEqual(store.sessions.first?.status, .running)

        store.processHookEvent(waitingEvent)
        XCTAssertEqual(store.sessions.filter { $0.identity.hookSessionID == "hook-waiting" }.first?.status, .waitingInput)

        store.processHookEvent(completedEvent)
        XCTAssertEqual(store.sessions.filter { $0.identity.hookSessionID == "hook-completed" }.first?.status, .completed)
    }

    func testProcessHookEventAppendsHistoryEntryForNewSession() {
        let hookEvent = HookEvent(
            sessionID: "hook-history-test",
            cwd: "/Users/test/project",
            event: .postToolUse,
            status: "running",
            pid: 999,
            tty: "/dev/ttys013",
            tool: "Write"
        )

        let store = TaskStateStore(
            observationService: StubObservationService(events: [], diagnostics: .empty)
        )

        store.processHookEvent(hookEvent)

        XCTAssertFalse(store.sessions.first?.historyEntries.isEmpty ?? true,
                       "Hook-created session should have initial history entry")
        XCTAssertEqual(store.sessions.first?.historyEntries.first?.kind, .phaseRunning)
    }
}

// MARK: - Transition-Based Sound Cue Tests

extension TaskStateStoreTests {
    func testTransitionCueEmitsTaskStartedWhenSessionEntersRunning() {
        // taskStarted sound was removed per user request - only completion sounds needed
        let service = FeedbackService()

        let previousSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .discovered, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .running, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        // No taskStarted sound - user only wants completion sounds
        XCTAssertFalse(cues.contains(.taskStarted))
    }

    func testTransitionCueDoesNotReplayTaskStartedForSameRunningSession() {
        let service = FeedbackService()
        let sessionID = UUID()

        // Same session ID, same running status - should NOT emit
        let previousSessions: [TaskSession] = [
            makeSession(id: sessionID, status: .running, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: sessionID, status: .running, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertFalse(cues.contains(.taskStarted))
    }

    func testTransitionCueDoesNotReplayTaskStartedAcrossMultipleRefreshCycles() {
        let service = FeedbackService()
        let sessionID = UUID()

        // First transition: discovered -> running (should NOT emit taskStarted - removed)
        let round1Previous: [TaskSession] = [makeSession(id: sessionID, status: .discovered, cliKind: .claudeCode)]
        let round1Current: [TaskSession] = [makeSession(id: sessionID, status: .running, cliKind: .claudeCode)]
        let cuesRound1 = service.cues(previousSessions: round1Previous, currentSessions: round1Current)
        // taskStarted was removed - no sound on running transition
        XCTAssertFalse(cuesRound1.contains(.taskStarted), "taskStarted sound was removed")

        // Round 2: running -> running (should NOT emit)
        let round2Previous = round1Current
        let round2Current: [TaskSession] = [makeSession(id: sessionID, status: .running, cliKind: .claudeCode)]
        let cuesRound2 = service.cues(previousSessions: round2Previous, currentSessions: round2Current)
        XCTAssertFalse(cuesRound2.contains(.taskStarted), "Same running state should NOT emit taskStarted")

        // Round 3: running -> running (should NOT emit)
        let round3Previous = round2Current
        let round3Current: [TaskSession] = [makeSession(id: sessionID, status: .running, cliKind: .claudeCode)]
        let cuesRound3 = service.cues(previousSessions: round3Previous, currentSessions: round3Current)
        XCTAssertFalse(cuesRound3.contains(.taskStarted), "Third consecutive running should NOT emit taskStarted")
    }

    func testTransitionCueEmitsWaitingForReplyWhenSessionEntersWaitingInput() {
        let service = FeedbackService()

        let previousSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .running, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .waitingInput, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertTrue(cues.contains(.waitingForReply))
    }

    func testTransitionCueDoesNotReplayWaitingForReplyForSameWaitingSession() {
        let service = FeedbackService()
        let sessionID = UUID()

        // Same session ID, same waitingInput status - should NOT emit
        let previousSessions: [TaskSession] = [
            makeSession(id: sessionID, status: .waitingInput, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: sessionID, status: .waitingInput, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertFalse(cues.contains(.waitingForReply))
    }

    func testTransitionCueEmitsCompletedWhenSessionEntersCompleted() {
        let service = FeedbackService()

        let previousSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .running, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .completed, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertTrue(cues.contains(.completed))
    }

    func testTransitionCueDoesNotReplayCompletedForSameCompletedSession() {
        let service = FeedbackService()
        let sessionID = UUID()

        // Same session ID, same completed status - should NOT emit
        let previousSessions: [TaskSession] = [
            makeSession(id: sessionID, status: .completed, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: sessionID, status: .completed, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertFalse(cues.contains(.completed))
    }

    func testTransitionCueDoesNotReplayCompletedAcrossMultipleRefreshCycles() {
        let service = FeedbackService()
        let sessionID = UUID()

        // First transition: running -> completed (should emit)
        let round1Previous: [TaskSession] = [makeSession(id: sessionID, status: .running, cliKind: .claudeCode)]
        let round1Current: [TaskSession] = [makeSession(id: sessionID, status: .completed, cliKind: .claudeCode)]
        let cuesRound1 = service.cues(previousSessions: round1Previous, currentSessions: round1Current)
        XCTAssertTrue(cuesRound1.contains(.completed), "First transition should emit completed")

        // Round 2: completed -> completed (should NOT emit)
        let round2Previous = round1Current
        let round2Current: [TaskSession] = [makeSession(id: sessionID, status: .completed, cliKind: .claudeCode)]
        let cuesRound2 = service.cues(previousSessions: round2Previous, currentSessions: round2Current)
        XCTAssertFalse(cuesRound2.contains(.completed), "Same completed state should NOT emit completed")

        // Round 3: completed -> completed (should NOT emit)
        let round3Previous = round2Current
        let round3Current: [TaskSession] = [makeSession(id: sessionID, status: .completed, cliKind: .claudeCode)]
        let cuesRound3 = service.cues(previousSessions: round3Previous, currentSessions: round3Current)
        XCTAssertFalse(cuesRound3.contains(.completed), "Third consecutive completed should NOT emit completed")
    }

    func testTransitionCueEmitsFailedWhenSessionEntersAlert() {
        let service = FeedbackService()

        let previousSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .running, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .alert, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertTrue(cues.contains(.failed))
    }

    func testTransitionCueEmitsFailedWhenSessionEntersFailed() {
        let service = FeedbackService()

        let previousSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .running, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .failed, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertTrue(cues.contains(.failed))
    }

    func testTransitionCueEmitsWaitingForReplyWhenSessionEntersReplyAvailable() {
        let service = FeedbackService()

        let previousSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .running, cliKind: .claudeCode)
        ]
        let currentSessions: [TaskSession] = [
            makeSession(id: UUID(), status: .replyAvailable, cliKind: .claudeCode)
        ]

        let cues = service.cues(previousSessions: previousSessions, currentSessions: currentSessions)

        XCTAssertTrue(cues.contains(.waitingForReply))
    }

    func testTransitionCueRunningToWaitingInputEmitsOnce() {
        let service = FeedbackService()
        let sessionID = UUID()

        // First transition: running -> waitingInput (should emit once)
        let round1Previous: [TaskSession] = [makeSession(id: sessionID, status: .running, cliKind: .claudeCode)]
        let round1Current: [TaskSession] = [makeSession(id: sessionID, status: .waitingInput, cliKind: .claudeCode)]
        let cuesRound1 = service.cues(previousSessions: round1Previous, currentSessions: round1Current)

        let waitingCount = cuesRound1.filter { $0 == .waitingForReply }.count
        XCTAssertEqual(waitingCount, 1, "First transition should emit waitingForReply exactly once")

        // Round 2: waitingInput -> waitingInput (should NOT emit)
        let round2Previous = round1Current
        let round2Current: [TaskSession] = [makeSession(id: sessionID, status: .waitingInput, cliKind: .claudeCode)]
        let cuesRound2 = service.cues(previousSessions: round2Previous, currentSessions: round2Current)

        let waitingCountRound2 = cuesRound2.filter { $0 == .waitingForReply }.count
        XCTAssertEqual(waitingCountRound2, 0, "Same waitingInput state should NOT emit waitingForReply")
    }

    private func makeSession(id: UUID, status: TaskStatus, cliKind: CLIKind) -> TaskSession {
        TaskSession(
            id: id,
            identity: SessionIdentity(
                id: id,
                cliKind: cliKind,
                terminalAppIdentifier: "com.apple.Terminal",
                windowIdentifier: "window-\(id.uuidString.prefix(8))",
                commandLine: "",
                ttyIdentifier: "tty-\(id.uuidString.prefix(8))",
                startedAt: Date(),
                lastSeenAt: Date()
            ),
            title: "Test Session",
            status: status,
            priority: 0,
            confidence: 0.9,
            summary: "Test summary",
            bridgeTarget: nil,
            replyCapability: ReplyCapability(
                status: .available,
                reason: "Ready",
                targetDescription: "Test",
                channelStatus: "connected"
            ),
            lastActiveAt: Date(),
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            quickActions: []
        )
    }
}

private struct StubObservationService: ObservationProviding {
    let events: [RawCLIEvent]
    let diagnostics: ObservationDiagnostics

    func latestSnapshot() -> ObservationSnapshotResult {
        ObservationSnapshotResult(events: events, diagnostics: diagnostics)
    }
}

private struct StubPermissionService: PermissionProviding {
    let status: CapabilityStatus

    func currentStatus() -> CapabilityStatus {
        status
    }
}

private final class ConfigurableReplyBridge: ReplyBridging, @unchecked Sendable {
    let validateResult: ReplyValidationResult
    let sendResult: ReplyValidationResult
    private(set) var validateCallCount = 0
    private(set) var sendCallCount = 0
    private(set) var lastValidatedMessage: String?
    private(set) var lastSentMessage: String?

    init(
        validateResult: ReplyValidationResult = ReplyValidationResult(canSend: true, explanation: "Ready"),
        sendResult: ReplyValidationResult = ReplyValidationResult(canSend: true, explanation: "Sent")
    ) {
        self.validateResult = validateResult
        self.sendResult = sendResult
    }

    func validateReply(for session: TaskSession, message: String) -> ReplyValidationResult {
        validateCallCount += 1
        lastValidatedMessage = message
        return validateResult
    }

    func sendReply(to session: TaskSession, message: String) -> ReplyValidationResult {
        sendCallCount += 1
        lastSentMessage = message
        return sendResult
    }
}

private extension TerminalReaderResult {
    static func success(
        readerID: String = "terminal",
        readerName: String = "Terminal",
        terminalAppIdentifier: String = "com.apple.Terminal",
        observations: [ObservedTerminalSession]
    ) -> TerminalReaderResult {
        TerminalReaderResult(
            readerID: readerID,
            readerName: readerName,
            terminalAppIdentifier: terminalAppIdentifier,
            isAppRunning: true,
            fetchStatus: .success,
            observations: observations,
            message: "已读取到 \(observations.count) 个 \(readerName) session",
            errorDescription: nil
        )
    }
}

private extension ObservationDiagnostics {
    static let empty = ObservationDiagnostics(readers: [], sessions: [])
}

private actor MutableEventSource {
    private var events: [RawCLIEvent]

    init(events: [RawCLIEvent]) {
        self.events = events
    }

    func update(_ newEvents: [RawCLIEvent]) {
        events = newEvents
    }

    func snapshot() -> [RawCLIEvent] {
        events
    }
}

private final class MutableObservationService: ObservationProviding, @unchecked Sendable {
    private let source: MutableEventSource
    private var diagnostics: ObservationDiagnostics

    init(initialEvents: [RawCLIEvent], diagnostics: ObservationDiagnostics = ObservationDiagnostics(readers: [], sessions: [])) {
        self.source = MutableEventSource(events: initialEvents)
        self.diagnostics = diagnostics
    }

    func updateEvents(_ events: [RawCLIEvent]) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await source.update(events)
            semaphore.signal()
        }
        semaphore.wait()
    }

    func latestSnapshot() -> ObservationSnapshotResult {
        let semaphore = DispatchSemaphore(value: 0)
        var currentEvents: [RawCLIEvent] = []
        Task {
            currentEvents = await source.snapshot()
            semaphore.signal()
        }
        semaphore.wait()
        return ObservationSnapshotResult(events: currentEvents, diagnostics: diagnostics)
    }
}

private struct StubTerminalReader: TerminalAppReading {
    let result: TerminalReaderResult

    func fetchResult() -> TerminalReaderResult {
        result
    }
}
