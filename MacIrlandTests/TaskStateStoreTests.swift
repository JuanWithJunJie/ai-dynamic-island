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
        XCTAssertEqual(store.topSession?.sourceCLI, .codex)
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
        let replyBridge = ConfigurableReplyBridge(validateResult: ReplyValidationResult(canSend: false, explanation: "Bridge unavailable"))
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

    func testPerformQuickActionAcceptedPathAppendsUserQuickActionHistory() throws {
        let replyBridge = ConfigurableReplyBridge(validateResult: ReplyValidationResult(canSend: true, explanation: "Ready to send"))
        let store = TaskStateStore(
            observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
            replyBridge: replyBridge
        )
        let session = try XCTUnwrap(store.sessions.first as TaskSession?)

        let result = store.performQuickAction(.continueExecution, for: session)

        XCTAssertTrue(result.canSend)
        XCTAssertEqual(result.explanation, "Ready to send")
        XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseWaitingInput, .userQuickAction])
        XCTAssertEqual(store.sessions.first?.historyEntries.last?.detail, ReplyActionType.continueExecution.defaultMessage)
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

    func testSelectSessionUpdatesSelectedSession() throws {
        let store = TaskStateStore(
            observationService: StubObservationService(events: prioritizedEvents, diagnostics: .empty)
        )
        let secondSession = try XCTUnwrap(store.sessions.last)

        store.selectSession(secondSession)

        XCTAssertEqual(store.selectedSession?.id, secondSession.id)
    }

    func testRefreshPreservesSelectedSessionWhenLogicalSessionRemains() throws {
        let source = MutableObservationService(initialEvents: prioritizedEvents)
        let store = TaskStateStore(observationService: source)
        let originalSecondSession = try XCTUnwrap(store.sessions.last)

        store.selectSession(originalSecondSession)
        source.updateEvents(refreshedEventsKeepingSameSessions)

        store.refresh()

        XCTAssertEqual(store.selectedSession?.id, originalSecondSession.id)
        XCTAssertEqual(store.selectedSession?.sourceCLI, .gemini)
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

    private var prioritizedEvents: [RawCLIEvent] {
        [
            RawCLIEvent(
                cliKind: .codex,
                snippet: "Waiting for input to continue",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "codex task",
                    commandLine: "codex",
                    ttyIdentifier: "ttys001"
                )
            ),
            RawCLIEvent(
                cliKind: .gemini,
                snippet: "finished generating summary",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "gemini task",
                    commandLine: "gemini",
                    ttyIdentifier: "ttys002"
                )
            )
        ]
    }

    private var refreshedEventsKeepingSameSessions: [RawCLIEvent] {
        [
            RawCLIEvent(
                cliKind: .codex,
                snippet: "Waiting for input to continue with extra details",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "codex task",
                    commandLine: "codex",
                    ttyIdentifier: "ttys001"
                )
            ),
            RawCLIEvent(
                cliKind: .gemini,
                snippet: "finished generating summary successfully",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "gemini task",
                    commandLine: "gemini",
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

private final class ConfigurableReplyBridge: ReplyBridging {
    let validateResult: ReplyValidationResult
    let sendResult: ReplyValidationResult

    init(
        validateResult: ReplyValidationResult = ReplyValidationResult(canSend: true, explanation: "Ready"),
        sendResult: ReplyValidationResult = ReplyValidationResult(canSend: true, explanation: "Sent")
    ) {
        self.validateResult = validateResult
        self.sendResult = sendResult
    }

    func validateReply(for session: TaskSession, message: String) -> ReplyValidationResult {
        validateResult
    }

    func sendReply(to session: TaskSession, message: String) -> ReplyValidationResult {
        sendResult
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
