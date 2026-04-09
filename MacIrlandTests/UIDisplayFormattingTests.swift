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
            ["发送文本", "继续执行", "等待输入"]
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

        XCTAssertEqual(presentation.statusText, "空闲")
        XCTAssertEqual(presentation.countText, "0 个会话")
    }

    func testCompactIslandPresentationUsesWaitingReplyCopyForWaitingSession() {
        let session = makeSession(status: .waitingInput)
        let summary = AppTaskSummary(runningCount: 1, waitingCount: 1, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "等待回复")
        XCTAssertEqual(presentation.countText, "2 个会话")
    }

    func testCompactIslandPresentationUsesRunningStateForActiveWork() {
        let session = makeSession(status: .running)
        let summary = AppTaskSummary(runningCount: 2, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "运行中")
        XCTAssertEqual(presentation.countText, "2 个会话")
    }

    @MainActor
    func testCompactIslandPresentationAccessibilityLabelIncludesStatusAndCount() {
        let session = makeSession(status: .running)
        let summary = AppTaskSummary(runningCount: 1, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.accessibilityLabel, "MacIrland，运行中，1 个会话")
    }

    @MainActor
    func testCompactIslandPresentationUsesWaitingReplyAccentForWaitingSession() {
        let session = makeSession(status: .waitingInput)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 1, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "等待回复")
        XCTAssertEqual(presentation.accentColor, IslandAccent.color(for: .waitingInput))
    }

    @MainActor
    func testCompactIslandPresentationUsesNeedsHandlingCopyForFailedSession() {
        let session = makeSession(status: .failed)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "需要处理")
    }

    @MainActor
    func testCompactIslandPresentationUsesAlertCopyForAlertSession() {
        let session = makeSession(status: .alert)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 1, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "发现异常")
    }

    @MainActor
    func testCompactIslandPresentationUsesDirectReplyCopyForReplyAvailableSession() {
        let session = makeSession(status: .replyAvailable)
        let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 0, topPrioritySessionID: nil)

        let presentation = CompactIslandPresentation(summary: summary, preferredSession: session, secondaryCount: 0)

        XCTAssertEqual(presentation.statusText, "可直接回复")
    }

    func testHighlightedIslandPresentationUsesWaitingSessionCopy() {
        let session = makeSession(status: .waitingInput)

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(presentation?.titleText, "UI refresh")
        XCTAssertEqual(presentation?.summaryText, "等待你确认、补充信息或继续执行。")
        XCTAssertEqual(presentation?.sourceText, "Claude Code")
    }

    func testHighlightedIslandPresentationReturnsNilForNonAttentionSession() {
        let session = makeSession(status: .running)

        XCTAssertNil(HighlightedIslandPresentation(topSession: session))
    }

    func testHighlightedIslandPresentationUsesRelativeLastActiveTime() {
        let session = makeSession(status: .failed)

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(presentation?.timeText, session.relativeLastActiveText)
    }

    @MainActor
    func testHighlightedIslandPresentationAccessibilityLabelIncludesSource() {
        let session = makeSession(status: .alert)

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(
            presentation?.accessibilityLabel,
            "MacIrland，UI refresh，Refreshing the panel UI.，来自 Claude Code"
        )
    }

    @MainActor
    func testHighlightedIslandPresentationUsesStatusAccentColor() {
        let session = makeSession(status: .failed)

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(presentation?.accentColor, IslandAccent.color(for: .failed))
    }

    func testHighlightedIslandPresentationPicksFirstVisibleQuickAction() {
        let session = makeSession(
            status: .waitingInput,
            quickActions: [.continueExecution, .retry, .customText]
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(presentation?.primaryAction, .continueExecution)
        XCTAssertEqual(presentation?.primaryActionTitle, "继续执行")
    }

    func testHighlightedIslandPresentationSkipsCustomTextWhenChoosingPrimaryAction() {
        let session = makeSession(
            status: .replyAvailable,
            quickActions: [.customText, .explainReason]
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(presentation?.primaryAction, .explainReason)
        XCTAssertEqual(presentation?.primaryActionTitle, "解释原因")
    }

    func testHighlightedIslandPresentationHasNoPrimaryActionWhenNoVisibleQuickActionsExist() {
        let session = makeSession(
            status: .failed,
            quickActions: [.customText]
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertNil(presentation?.primaryAction)
        XCTAssertNil(presentation?.primaryActionTitle)
    }

    func testHighlightedIslandPresentationPrimaryActionAvailableWhenBridgeReady() {
        let session = makeSession(
            status: .waitingInput,
            quickActions: [.continueExecution],
            bridgeTarget: BridgeTarget(
                cliKind: .claudeCode,
                sessionID: UUID(),
                terminalContext: "Claude Code · ui",
                channelType: "applescript-terminal",
                displayName: "Claude Code"
            )
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertTrue(presentation?.primaryActionAvailable ?? false)
        XCTAssertNil(presentation?.primaryActionUnavailableReason)
    }

    func testHighlightedIslandPresentationPrimaryActionUnavailableWhenBridgeUnavailable() {
        let session = makeSession(
            status: .waitingInput,
            quickActions: [.continueExecution],
            bridgeTarget: nil,
            replyCapabilityStatus: .unavailable,
            replyCapabilityReason: "终端自动化权限未授权，请检查系统设置。"
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertFalse(presentation?.primaryActionAvailable ?? true)
        XCTAssertEqual(presentation?.primaryActionUnavailableReason, "终端自动化权限未授权，请检查系统设置。")
    }

    func testHighlightedIslandPresentationKeepsPrimaryActionForWaitingSession() {
        let session = makeSession(
            status: .waitingInput,
            quickActions: [.retry, .continueExecution]
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertEqual(presentation?.primaryAction, .retry)
        XCTAssertEqual(presentation?.primaryActionTitle, "重试")
    }

    func testHighlightedIslandPresentationCanRenderWithoutPrimaryAction() {
        let session = makeSession(
            status: .alert,
            quickActions: [.customText]
        )

        let presentation = HighlightedIslandPresentation(topSession: session)

        XCTAssertNotNil(presentation)
        XCTAssertNil(presentation?.primaryActionTitle)
    }

    func testHighlightedIslandPresentationAutoCollapseDelayIsNilForWaitingInput() {
        let session = makeSession(status: .waitingInput)
        guard let presentation = HighlightedIslandPresentation(topSession: session) else {
            XCTFail("Expected non-nil presentation for waitingInput session")
            return
        }
        XCTAssertNil(presentation.autoCollapseDelay)
    }

    func testHighlightedIslandPresentationAutoCollapseDelayIsNilForFailedSession() {
        let session = makeSession(status: .failed)
        guard let presentation = HighlightedIslandPresentation(topSession: session) else {
            XCTFail("Expected non-nil presentation for failed session")
            return
        }
        XCTAssertNil(presentation.autoCollapseDelay)
    }

    func testHighlightedIslandPresentationAutoCollapseDelayUsesEightSecondsForAlert() {
        let session = makeSession(status: .alert)
        guard let presentation = HighlightedIslandPresentation(topSession: session) else {
            XCTFail("Expected non-nil presentation for alert session")
            return
        }
        XCTAssertEqual(presentation.autoCollapseDelay, 8)
    }

    func testHighlightedIslandPresentationAutoCollapseDelayUsesTwelveSecondsForReplyAvailable() {
        let session = makeSession(status: .replyAvailable)
        guard let presentation = HighlightedIslandPresentation(topSession: session) else {
            XCTFail("Expected non-nil presentation for replyAvailable session")
            return
        }
        XCTAssertEqual(presentation.autoCollapseDelay, 12)
    }

    func testHighlightedIslandPresentationKeepsContextLostPersistent() {
        let session = makeSession(status: .contextLost)
        guard let presentation = HighlightedIslandPresentation(topSession: session) else {
            XCTFail("Expected non-nil presentation for contextLost session")
            return
        }
        XCTAssertNil(presentation.autoCollapseDelay)
    }

    func testHighlightedIslandPresentationKeepsWaitingInputPersistentEvenWithPrimaryAction() {
        let session = makeSession(
            status: .waitingInput,
            quickActions: [.continueExecution, .customText]
        )
        guard let presentation = HighlightedIslandPresentation(topSession: session) else {
            XCTFail("Expected non-nil presentation for waitingInput session")
            return
        }
        XCTAssertEqual(presentation.primaryActionTitle, "继续执行")
        XCTAssertNil(presentation.autoCollapseDelay)
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

    @MainActor
    func testPanelUsesSubduedCardToneForSessionList() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("PanelCard(tone: .subdued, padding: 16)"))
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

    private func makeSession(
        status: TaskStatus = .running,
        terminalAppIdentifier: String = "com.apple.Terminal",
        historyEntries: [SessionHistoryEntry] = [],
        quickActions: [ReplyActionType] = [.continueExecution],
        bridgeTarget: BridgeTarget? = nil,
        replyCapabilityStatus: ReplyCapabilityStatus = .available,
        replyCapabilityReason: String = "Ready"
    ) -> TaskSession {
        TaskSession(
            identity: SessionIdentity(
                cliKind: .claudeCode,
                terminalAppIdentifier: terminalAppIdentifier,
                windowIdentifier: "Claude Code · ui",
                ttyIdentifier: "ttys001",
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 0)
            ),
            title: "UI refresh",
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
}
