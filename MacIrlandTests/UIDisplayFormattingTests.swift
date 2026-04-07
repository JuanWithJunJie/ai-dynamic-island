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

    func testTimelineEntriesSortNewestFirstAcrossEventsAndMessages() {
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
                    timestamp: Date(timeIntervalSince1970: 100),
                    kind: .started,
                    message: "Started scan"
                )
            ],
            recentMessages: [
                MessageSnippet(
                    timestamp: Date(timeIntervalSince1970: 200),
                    kind: .assistant,
                    text: "Latest assistant update"
                )
            ],
            quickActions: [.continueExecution]
        )

        XCTAssertEqual(session.timelineEntries.map(\.title), ["最新消息", "Started"])
        XCTAssertEqual(session.timelineEntries.first?.detail, "Latest assistant update")
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
