import XCTest
@testable import MacIrlandKit
@testable import MacIrlandApp

final class UIDisplayFormattingTests: XCTestCase {
    func testTerminalDisplayNameUsesFriendlyAppNames() {
        XCTAssertEqual(makeSession(terminalAppIdentifier: "com.apple.Terminal").terminalDisplayName, "Terminal")
        XCTAssertEqual(makeSession(terminalAppIdentifier: "com.googlecode.iterm2").terminalDisplayName, "iTerm2")
        XCTAssertEqual(makeSession(terminalAppIdentifier: "com.example.shell").terminalDisplayName, "Shell")
    }

    func testAttentionCountSumsWaitingAndAlertSessions() {
        let summary = AppTaskSummary(
            runningCount: 2,
            waitingCount: 3,
            completedCount: 1,
            alertCount: 2,
            topPrioritySessionID: nil
        )

        XCTAssertEqual(summary.attentionCount, 5)
        XCTAssertEqual(summary.totalCount, 8)
    }

    func testMenuBarPresentationPrefersAttentionCount() {
        let summary = AppTaskSummary(
            runningCount: 2,
            waitingCount: 1,
            completedCount: 4,
            alertCount: 2,
            topPrioritySessionID: nil
        )

        let presentation = MenuBarStatusPresentation(summary: summary, topSession: makeSession(status: .waitingInput))

        XCTAssertEqual(presentation.countText, "3")
        XCTAssertEqual(presentation.accessibilityLabel, "MacIrland，3 个需要关注")
    }

    func testMenuBarPresentationFallsBackToRunningCount() {
        let summary = AppTaskSummary(
            runningCount: 2,
            waitingCount: 0,
            completedCount: 4,
            alertCount: 0,
            topPrioritySessionID: nil
        )

        let presentation = MenuBarStatusPresentation(summary: summary, topSession: makeSession(status: .running))

        XCTAssertEqual(presentation.countText, "2")
        XCTAssertEqual(presentation.accessibilityLabel, "MacIrland，2 个运行中")
    }

    func testPrimaryGuidanceTextHighlightsUserActionForWaitingInput() {
        let session = makeSession(status: .waitingInput)

        XCTAssertEqual(session.primaryGuidanceText, "等待你确认、补充信息或继续执行。")
    }

    func testHistoryEntryFormatsWaitingPhaseRow() {
        let entry = SessionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 200),
            kind: .phaseWaitingInput,
            title: "等待输入",
            detail: "Need user input",
            relatedStatus: .waitingInput
        )

        XCTAssertEqual(entry.systemImage, "hand.raised.fill")
        XCTAssertEqual(entry.tint, .waitingInput)
        XCTAssertEqual(entry.timeText.count, 5)
        XCTAssertEqual(entry.timeText.filter { $0 == ":" }.count, 1)
    }

    func testTimelineEntriesComeFromHistoryEntriesSortedNewestFirst() {
        let session = TaskSession(
            identity: SessionIdentity(
                cliKind: .claudeCode,
                terminalAppIdentifier: "com.apple.Terminal",
                windowIdentifier: "Claude Code · timeline",
                commandLine: "",
                ttyIdentifier: "ttys007",
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 300)
            ),
            title: "Timeline session",
            status: .running,
            priority: 1,
            confidence: 0.91,
            summary: "Reviewing timeline view",
            bridgeTarget: nil,
            replyCapability: ReplyCapability(
                status: .manualConfirmationRequired,
                reason: "Mock bridge",
                targetDescription: "Claude Code",
                channelStatus: "mock"
            ),
            lastActiveAt: Date(timeIntervalSince1970: 300),
            evidence: [],
            recentEvents: [
                SessionEvent(
                    timestamp: Date(timeIntervalSince1970: 500),
                    kind: .completed,
                    message: "Old synthetic event should not drive ordering"
                )
            ],
            recentMessages: [
                MessageSnippet(
                    timestamp: Date(timeIntervalSince1970: 600),
                    kind: .assistant,
                    text: "Old synthetic message should not drive ordering"
                )
            ],
            historyEntries: [
                SessionHistoryEntry(
                    timestamp: Date(timeIntervalSince1970: 100),
                    kind: .phaseRunning,
                    title: "运行中",
                    detail: "Started scan",
                    relatedStatus: .running
                ),
                SessionHistoryEntry(
                    timestamp: Date(timeIntervalSince1970: 200),
                    kind: .phaseWaitingInput,
                    title: "等待输入",
                    detail: "Need user confirmation",
                    relatedStatus: .waitingInput
                ),
                SessionHistoryEntry(
                    timestamp: Date(timeIntervalSince1970: 150),
                    kind: .phaseReplyAvailable,
                    title: "可回复",
                    detail: "Reply is available",
                    relatedStatus: .replyAvailable
                )
            ],
            quickActions: [.continueExecution]
        )

        XCTAssertEqual(session.timelineEntries.map(\.title), ["等待输入", "可回复", "运行中"])
        XCTAssertEqual(session.timelineEntries.map(\.detail), ["Need user confirmation", "Reply is available", "Started scan"])
    }

    func testTimelineEntriesKeepUserActionHistoryEntriesInOrdering() {
        let session = TaskSession(
            identity: SessionIdentity(
                cliKind: .claudeCode,
                terminalAppIdentifier: "com.apple.Terminal",
                windowIdentifier: "Claude Code · history",
                commandLine: "",
                ttyIdentifier: "ttys008",
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 300)
            ),
            title: "History session",
            status: .waitingInput,
            priority: 1,
            confidence: 0.91,
            summary: "Reviewing runtime history",
            bridgeTarget: nil,
            replyCapability: ReplyCapability(
                status: .manualConfirmationRequired,
                reason: "Mock bridge",
                targetDescription: "Claude Code",
                channelStatus: "mock"
            ),
            lastActiveAt: Date(timeIntervalSince1970: 300),
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            historyEntries: [
                SessionHistoryEntry(
                    timestamp: Date(timeIntervalSince1970: 100),
                    kind: .phaseRunning,
                    title: "运行中",
                    detail: "Started scan",
                    relatedStatus: .running
                ),
                SessionHistoryEntry(
                    timestamp: Date(timeIntervalSince1970: 250),
                    kind: .userQuickAction,
                    title: "快速操作 · 继续执行",
                    detail: "请继续执行。",
                    relatedStatus: .waitingInput
                ),
                SessionHistoryEntry(
                    timestamp: Date(timeIntervalSince1970: 200),
                    kind: .phaseWaitingInput,
                    title: "等待输入",
                    detail: "Need user confirmation",
                    relatedStatus: .waitingInput
                )
            ],
            quickActions: [.continueExecution]
        )

        XCTAssertEqual(session.timelineEntries.map(\.kind), [.userQuickAction, .phaseWaitingInput, .phaseRunning])
        XCTAssertEqual(session.timelineEntries.map(\.title), ["快速操作 · 继续执行", "等待输入", "运行中"])
    }

    func testTimelineRowsUseHistoryEntryPresentationFieldsForAttentionAndUserActions() {
        let waitingEntry = SessionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 200),
            kind: .phaseWaitingInput,
            title: "等待输入",
            detail: "Need user confirmation",
            relatedStatus: .waitingInput
        )
        let failedEntry = SessionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 210),
            kind: .phaseFailed,
            title: "执行失败",
            detail: "Command exited with status 1",
            relatedStatus: .failed
        )
        let userActionEntry = SessionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 220),
            kind: .userQuickAction,
            title: "快速操作 · 继续执行",
            detail: "请继续执行。",
            relatedStatus: .waitingInput
        )

        XCTAssertEqual(waitingEntry.systemImage, "hand.raised.fill")
        XCTAssertEqual(waitingEntry.tint, .waitingInput)
        XCTAssertEqual(failedEntry.systemImage, "xmark.octagon.fill")
        XCTAssertEqual(failedEntry.tint, .failed)
        XCTAssertEqual(userActionEntry.systemImage, "person.fill.badge.plus")
        XCTAssertEqual(userActionEntry.title, "快速操作 · 继续执行")
        XCTAssertEqual(userActionEntry.detail, "请继续执行。")
    }

    func testTimelinePreviewEntriesDefaultToNewestThreeItems() {
        let session = makeSession(
            status: .waitingInput,
            historyEntries: [
                makeHistoryEntry(offset: 10, kind: .phaseRunning, title: "运行中"),
                makeHistoryEntry(offset: 20, kind: .phaseWaitingInput, title: "等待输入"),
                makeHistoryEntry(offset: 30, kind: .userQuickAction, title: "继续执行"),
                makeHistoryEntry(offset: 40, kind: .userCustomReply, title: "发送文本")
            ]
        )

        XCTAssertEqual(session.timelinePreviewEntries().map(\.title), ["发送文本", "继续执行", "等待输入"])
    }

    func testCompactSessionSubtitlePrefersActionableGuidanceForWaitingSession() {
        let session = makeSession(status: .waitingInput)

        XCTAssertEqual(session.compactSessionSubtitle, "等待你确认、补充信息或继续执行。")
    }

    func testCompactSessionSubtitleFallsBackToSummaryForRunningSession() {
        let session = makeSession(status: .running)

        XCTAssertEqual(session.compactSessionSubtitle, "Refreshing the panel UI.")
    }

    func testDiagnosticsSummaryUsesBlockedExplanationWhenObservationFails() {
        let blocked = CapabilityStatus(
            accessibilityGranted: true,
            localOnlyProcessing: true,
            explanation: "未授权自动化",
            observationBlocked: true
        )

        XCTAssertEqual(blocked.panelDiagnosticsSummary, "终端读取失败，展开诊断查看权限或识别问题。")
        XCTAssertTrue(blocked.showsDiagnosticsExpandedByDefault)
    }

    func testPanelDiagnosticsSummaryDefaultsToCapabilityExplanationWhenHealthy() {
        let healthy = CapabilityStatus(
            accessibilityGranted: true,
            localOnlyProcessing: true,
            explanation: "当前使用本地观察链路。",
            observationBlocked: false
        )

        XCTAssertEqual(healthy.panelDiagnosticsSummary, "当前使用本地观察链路。")
        XCTAssertFalse(healthy.showsDiagnosticsExpandedByDefault)
    }

    @MainActor
    func testSessionDetailTimelineSubtitleDescribesPreviewInsteadOfFullHistory() {
        XCTAssertEqual(SessionDetailView.timelineSubtitle, "仅显示最近关键阶段。")
    }

    @MainActor
    func testSessionDetailViewUsesTimelinePreviewEntriesForRenderedTimeline() {
        let session = makeSession(
            status: .waitingInput,
            historyEntries: [
                makeHistoryEntry(offset: 10, kind: .phaseRunning, title: "运行中"),
                makeHistoryEntry(offset: 20, kind: .phaseWaitingInput, title: "等待输入"),
                makeHistoryEntry(offset: 30, kind: .userQuickAction, title: "继续执行"),
                makeHistoryEntry(offset: 40, kind: .userCustomReply, title: "发送文本")
            ]
        )

        XCTAssertEqual(
            SessionDetailView.renderedTimelineEntries(for: session).map(\.title),
            ["发送文本", "继续执行"]
        )
    }

    @MainActor
    func testSessionDetailViewVisibleQuickActionsExcludeCustomText() {
        let session = makeSession(status: .waitingInput, quickActions: [.continueExecution, .customText, .retry])

        XCTAssertEqual(
            SessionDetailView.visibleQuickActions(for: session),
            [.continueExecution, .retry]
        )
    }

    func testCompactIslandPresentationUsesIdleStateWhenNoSessionsExist() {
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: nil, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
        XCTAssertEqual(presentation.countText, "0")
    }

    func testCompactIslandPresentationUsesWaitingReplyCopyForWaitingSession() {
        let session = makeSession(status: .waitingInput)
        let summary = AppTaskSummary(runningCount: 1, waitingCount: 1, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
        XCTAssertEqual(presentation.countText, "2")
    }

    func testCompactIslandPresentationUsesRunningStateForActiveWork() {
        let session = makeSession(status: .running)
        let summary = AppTaskSummary(runningCount: 2, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
        XCTAssertEqual(presentation.countText, "2")
    }

    @MainActor
    func testCompactIslandPresentationAccessibilityLabelIncludesStatusAndCount() {
        let session = makeSession(status: .running)
        let summary = AppTaskSummary(runningCount: 1, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.accessibilityLabel, "MacIrland，，1")  // No status text in compact mode
    }

    @MainActor
    func testCompactIslandPresentationUsesWaitingReplyAccentForWaitingSession() {
        let session = makeSession(status: .waitingInput)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 1, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
        XCTAssertEqual(presentation.accentColor, IslandAccent.color(for: .waitingInput))
    }

    @MainActor
    func testCompactIslandPresentationUsesNeedsHandlingCopyForFailedSession() {
        let session = makeSession(status: .failed)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
    }

    @MainActor
    func testCompactIslandPresentationUsesAlertCopyForAlertSession() {
        let session = makeSession(status: .alert)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 1, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
    }

    @MainActor
    func testCompactIslandPresentationUsesDirectReplyCopyForReplyAvailableSession() {
        let session = makeSession(status: .replyAvailable)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "")  // No status text in compact mode
    }

    @MainActor
    func testPanelHeaderUsesSingleSentenceSummaryInsteadOfMultipleDashboardChips() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("FlowChips"))
    }

    func testPanelHeaderSubtitleStaysFocusedOnCurrentWorkInsteadOfGlobalCounts() {
        let session = makeSession(status: .waitingInput)

        XCTAssertEqual(session.compactSessionSubtitle, "等待你确认、补充信息或继续执行。")
    }

    func testCompactSessionSubtitleStillDrivesSessionListCopy() {
        let session = makeSession(status: .running)

        XCTAssertEqual(session.compactSessionSubtitle, "Refreshing the panel UI.")
    }

    func testProjectDisplayNamePrefersTitleOverSummaryForPrimaryLabels() {
        let session = makeSession(status: .running, title: "macirland")

        XCTAssertEqual(session.projectDisplayName, "macirland")
        XCTAssertNotEqual(session.projectDisplayName, session.summary)
    }

    func testProjectDisplayNameExtractsProjectFromPrefixedHookTitle() {
        let session = makeSession(status: .running, title: "Running Claude Code terminal session: macirland")

        XCTAssertEqual(session.projectDisplayName, "macirland")
    }

    func testProjectDisplayNameFallsBackToWindowIdentifierWhenSessionNameIsTruncated() {
        let session = TaskSession(
            identity: SessionIdentity(
                cliKind: .claudeCode,
                terminalAppIdentifier: "com.googlecode.iterm2",
                windowIdentifier: "test — ✳ Claude Code",
                commandLine: "",
                ttyIdentifier: "ttys009",
                sessionName: "✳ C",
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 0)
            ),
            title: "Claude Code",
            status: .running,
            priority: 1,
            confidence: 0.92,
            summary: "Refreshing the panel UI.",
            bridgeTarget: nil,
            replyCapability: ReplyCapability(
                status: .available,
                reason: "Ready",
                targetDescription: "Claude Code",
                channelStatus: "mock"
            ),
            lastActiveAt: Date(timeIntervalSince1970: 0),
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            historyEntries: [],
            quickActions: [.continueExecution]
        )

        XCTAssertEqual(session.projectDisplayName, "test")
    }

    func testProjectDisplayNameIgnoresSingleCharacterSessionNameArtifacts() {
        let session = makeSession(
            status: .running,
            title: "Claude Code",
            sessionName: "C"
        )

        XCTAssertEqual(session.projectDisplayName, "ui")
    }

    func testBuiltInAdapterPrefersWindowTitleProjectOverSnippetPrefix() {
        let event = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running Claude Code terminal session: · Claude C",
            transcript: "",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.googlecode.iterm2",
                windowTitle: "test — ✳ Claude Code",
                fullWindowName: "",
                commandLine: "claude",
                ttyIdentifier: "/dev/ttys002",
                isBusy: true,
                sessionName: "✳ C"
            )
        )

        let session = BuiltInCLIAdapter.claudeCode.buildSession(from: event)

        XCTAssertEqual(session?.title, "test")
    }

    func testProjectDisplayNameIsUsedForHoverExpandStatusStripTitle() {
        let session = makeSession(
            status: .running,
            title: "Running Claude Code terminal session: macirland"
        )

        XCTAssertEqual(session.projectDisplayName, "macirland")
        XCTAssertNotEqual(session.projectDisplayName, session.title)
    }

    func testPanelUsesSubduedCardToneForSessionList() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("PanelCard(tone: .subdued, padding: 14)"))
    }

    func testDiagnosticsSummaryStillUsesBlockedExplanationWhenNeeded() {
        let blocked = CapabilityStatus(
            accessibilityGranted: true,
            localOnlyProcessing: true,
            explanation: "未授权自动化",
            observationBlocked: true
        )

        XCTAssertEqual(blocked.panelDiagnosticsSummary, "终端读取失败，展开诊断查看权限或识别问题。")
    }

    @MainActor
    func testPanelEmptyWorkspaceCopyDescribesSecondLayerRole() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("这里是 island 的二级详情层"))
    }

    @MainActor
    func testReplyBridgeExplanationsAreUserFacing() {
        let service = MockReplyBridgeService()

        let emptyResult = service.validateReply(for: makeSession(), message: "   \n")
        XCTAssertFalse(emptyResult.explanation.contains("AppleScript"))
        XCTAssertFalse(emptyResult.explanation.contains("NSAppleEvent"))
        XCTAssertFalse(emptyResult.explanation.contains("bridge"))
        XCTAssertFalse(emptyResult.explanation.contains("Impl"))

        let unavailableCapabilityResult = service.validateReply(
            for: makeSession(
                bridgeTarget: BridgeTarget(
                    cliKind: .claudeCode,
                    sessionID: UUID(),
                    terminalContext: "Claude Code · reply",
                    channelType: "applescript-terminal",
                    displayName: "Claude Code · reply"
                ),
                replyCapabilityStatus: .unavailable,
                replyCapabilityReason: "终端自动化权限未授权。"
            ),
            message: "continue"
        )
        XCTAssertEqual(unavailableCapabilityResult.explanation, "终端自动化权限未授权。")
        XCTAssertFalse(unavailableCapabilityResult.explanation.contains("status"))
    }

    @MainActor
    func testReplyBridgeSuccessExplanationReferencesTerminalApp() {
        let service = MockReplyBridgeService()
        let session = makeSession(
            bridgeTarget: BridgeTarget(
                cliKind: .claudeCode,
                sessionID: UUID(),
                terminalContext: "Claude Code · reply",
                channelType: "applescript-terminal",
                displayName: "Claude Code · reply"
            )
        )

        let result = service.sendReply(to: session, message: "continue")

        XCTAssertTrue(result.explanation.contains("Claude Code"))
        XCTAssertTrue(result.canSend || result.explanation.contains("重试") || result.explanation.contains("刷新"))
    }

    func testSessionDetailTimelinePreviewEntriesDefaultToNewestTwoItems() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/SessionDetailView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("prefix(2)") || source.contains("limit: 2"))
    }

    func testSessionDetailFreeInputUsesCollapsedDisclosure() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/SessionDetailView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("DisclosureGroup"))
    }

    func testSessionPickerUsesSecondaryNavigationCopy() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/SessionPickerView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("其他会话") || source.contains("更多会话"))
    }

    private func makeSession(
        status: TaskStatus = .running,
        terminalAppIdentifier: String = "com.apple.Terminal",
        historyEntries: [SessionHistoryEntry] = [],
        quickActions: [ReplyActionType] = [.continueExecution],
        bridgeTarget: BridgeTarget? = nil,
        replyCapabilityStatus: ReplyCapabilityStatus = .available,
        replyCapabilityReason: String = "Ready",
        title: String = "UI refresh",
        sessionName: String = ""
    ) -> TaskSession {
        TaskSession(
            identity: SessionIdentity(
                cliKind: .claudeCode,
                terminalAppIdentifier: terminalAppIdentifier,
                windowIdentifier: "Claude Code · ui",
                commandLine: "",
                ttyIdentifier: "ttys001",
                sessionName: sessionName,
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 0)
            ),
            title: title,
            status: status,
            priority: 1,
            confidence: 0.92,
            summary: "Refreshing the panel UI.",
            bridgeTarget: bridgeTarget,
            replyCapability: ReplyCapability(
                status: replyCapabilityStatus,
                reason: replyCapabilityReason,
                targetDescription: "Claude Code",
                channelStatus: "mock"
            ),
            lastActiveAt: Date(timeIntervalSince1970: 0),
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            historyEntries: historyEntries,
            quickActions: quickActions
        )
    }

    private func makeHistoryEntry(offset: TimeInterval, kind: SessionHistoryKind, title: String) -> SessionHistoryEntry {
        SessionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: offset),
            kind: kind,
            title: title,
            detail: title,
            relatedStatus: .waitingInput
        )
    }

    func testWaitingAndReplySessionsUseDistinctWaitingAnimatedStatus() {
        // waitingInput should NOT map to idle - it should be distinct "waiting" state
        XCTAssertEqual(TaskStatus.waitingInput.animatedStatus, .waiting)
        XCTAssertEqual(TaskStatus.replyAvailable.animatedStatus, .waiting)

        // idle (no session) should remain idle
        XCTAssertEqual(TaskStatus.discovered.animatedStatus, .idle)
        XCTAssertEqual(TaskStatus.recognizing.animatedStatus, .idle)

        // running stays running
        XCTAssertEqual(TaskStatus.running.animatedStatus, .running)

        // completed stays completed
        XCTAssertEqual(TaskStatus.completed.animatedStatus, .completed)

        // waiting is visually distinct from idle and running
        XCTAssertNotEqual(TaskStatus.waitingInput.animatedStatus, .idle)
        XCTAssertNotEqual(TaskStatus.waitingInput.animatedStatus, .running)
        XCTAssertNotEqual(TaskStatus.replyAvailable.animatedStatus, .idle)
        XCTAssertNotEqual(TaskStatus.replyAvailable.animatedStatus, .running)
    }

    // MARK: - Session Identity Diagnostics

    func testObservationSessionDiagnosticExposesHookSessionID() {
        let diagnostic = ObservationSessionDiagnostic(
            terminalAppIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            commandLine: "claude",
            ttyIdentifier: "ttys005",
            transcriptPreview: "Hello",
            normalizedTranscriptPreview: "Hello",
            recognizedCLIKind: .claudeCode,
            inferredStatus: .running,
            decisionReason: "matched claude code",
            matchedSignals: 1,
            confidence: 0.85,
            normalizedTail: "Hello",
            hookSessionID: "hook-abc123"
        )

        XCTAssertEqual(diagnostic.hookSessionID, "hook-abc123")
    }

    func testObservationSessionDiagnosticShowsSourceAsHookOnly() {
        let diagnostic = ObservationSessionDiagnostic(
            terminalAppIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            commandLine: "claude",
            ttyIdentifier: "ttys005",
            transcriptPreview: "Hello",
            normalizedTranscriptPreview: "Hello",
            recognizedCLIKind: .claudeCode,
            inferredStatus: .running,
            decisionReason: "matched claude code",
            matchedSignals: 1,
            confidence: 0.85,
            normalizedTail: "Hello",
            hookSessionID: "hook-abc123",
            sessionSource: .hookOnly
        )

        XCTAssertEqual(diagnostic.sessionSource, .hookOnly)
        XCTAssertEqual(diagnostic.sessionSource.description, "hook")
    }

    func testObservationSessionDiagnosticShowsSourceAsAppleScriptOnly() {
        let diagnostic = ObservationSessionDiagnostic(
            terminalAppIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            commandLine: "claude",
            ttyIdentifier: "ttys005",
            transcriptPreview: "Hello",
            normalizedTranscriptPreview: "Hello",
            recognizedCLIKind: .claudeCode,
            inferredStatus: .running,
            decisionReason: "matched claude code",
            matchedSignals: 1,
            confidence: 0.85,
            normalizedTail: "Hello",
            hookSessionID: nil,
            sessionSource: .appleScriptOnly
        )

        XCTAssertEqual(diagnostic.sessionSource, .appleScriptOnly)
        XCTAssertEqual(diagnostic.sessionSource.description, "AppleScript")
    }

    func testObservationSessionDiagnosticShowsSourceAsMerged() {
        let diagnostic = ObservationSessionDiagnostic(
            terminalAppIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            commandLine: "claude",
            ttyIdentifier: "ttys005",
            transcriptPreview: "Hello",
            normalizedTranscriptPreview: "Hello",
            recognizedCLIKind: .claudeCode,
            inferredStatus: .running,
            decisionReason: "matched claude code",
            matchedSignals: 1,
            confidence: 0.85,
            normalizedTail: "Hello",
            hookSessionID: "hook-abc123",
            sessionSource: .merged
        )

        XCTAssertEqual(diagnostic.sessionSource, .merged)
        XCTAssertEqual(diagnostic.sessionSource.description, "hook + AppleScript")
    }

    // MARK: - Jump Diagnostics

    func testJumpDiagnosticExposesMatchBasis() {
        let jumpDiagnostic = JumpDiagnostic(
            success: true,
            matchBasis: .termSessionID("TERM_SESSION_ID=abc123"),
            failureReason: nil
        )

        XCTAssertTrue(jumpDiagnostic.success)
        XCTAssertEqual(jumpDiagnostic.matchBasis?.description, "TERM_SESSION_ID=abc123")
        XCTAssertNil(jumpDiagnostic.failureReason)
    }

    func testJumpDiagnosticExposesFailureReason() {
        let jumpDiagnostic = JumpDiagnostic(
            success: false,
            matchBasis: nil,
            failureReason: "AppleScript error: Permission denied"
        )

        XCTAssertFalse(jumpDiagnostic.success)
        XCTAssertNil(jumpDiagnostic.matchBasis)
        XCTAssertEqual(jumpDiagnostic.failureReason, "AppleScript error: Permission denied")
    }

    func testJumpDiagnosticMatchBasisDescribesTTYBasedMatch() {
        let jumpDiagnostic = JumpDiagnostic(
            success: true,
            matchBasis: .tty("/dev/ttys005"),
            failureReason: nil
        )

        XCTAssertEqual(jumpDiagnostic.matchBasis?.description, "tty /dev/ttys005")
    }

    func testJumpDiagnosticMatchBasisDescribesProcessFallbackMatch() {
        let jumpDiagnostic = JumpDiagnostic(
            success: true,
            matchBasis: .processFallback,
            failureReason: nil
        )

        XCTAssertEqual(jumpDiagnostic.matchBasis?.description, "process fallback (claude)")
    }
}
