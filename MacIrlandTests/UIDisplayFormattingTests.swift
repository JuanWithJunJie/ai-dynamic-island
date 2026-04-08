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

    @MainActor
    func testSessionDetailViewUsesPhaseHistoryTimelineSubtitle() {
        XCTAssertEqual(SessionDetailView.timelineSubtitle, "按时间倒序查看阶段变化、用户操作和回复痕迹。")
    }

    private func makeSession(
        status: TaskStatus = .running,
        terminalAppIdentifier: String = "com.apple.Terminal"
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
            quickActions: [.continueExecution]
        )
    }
}
