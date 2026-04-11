import XCTest
@testable import MacIrlandKit

final class ReplyBridgeServiceTests: XCTestCase {
    func testValidateReplyRejectsEmptyMessage() {
        let service = MockReplyBridgeService()

        let result = service.validateReply(for: makeSession(), message: "   \n")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "回复内容不能为空。")
    }

    func testValidateReplyRejectsUnsupportedCLI() {
        let service = MockReplyBridgeService()

        let result = service.validateReply(for: makeSession(cliKind: .codex), message: "continue")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "当前仅支持向 Claude Code 会话发送回复。")
    }

    func testValidateReplyRejectsMissingBridgeTarget() {
        let service = MockReplyBridgeService()

        let result = service.validateReply(for: makeSession(bridgeTarget: nil), message: "continue")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "当前没有可用的目标会话。")
    }

    func testValidateReplyRejectsSessionTargetMismatch() {
        let service = MockReplyBridgeService()
        let mismatchedTarget = BridgeTarget(
            cliKind: .claudeCode,
            sessionID: UUID(),
            terminalContext: "different-window",
            channelType: "applescript-terminal",
            displayName: "Claude Code · mismatch"
        )

        let result = service.validateReply(for: makeSession(bridgeTarget: mismatchedTarget), message: "continue")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "目标 Claude Code 会话已变化或不存在，请刷新后重试。")
    }

    func testValidateReplyRejectsUnsupportedTerminal() {
        let service = MockReplyBridgeService()

        let result = service.validateReply(
            for: makeSession(terminalAppIdentifier: "com.example.terminal"),
            message: "continue"
        )

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "当前仅支持通过 Terminal 或 iTerm 向 Claude Code 会话发送回复。")
    }

    func testSendReplyReturnsMismatchFailureWithoutSending() {
        let service = MockReplyBridgeService()
        let mismatchedTarget = BridgeTarget(
            cliKind: .claudeCode,
            sessionID: UUID(),
            terminalContext: "different-window",
            channelType: "applescript-terminal",
            displayName: "Claude Code · mismatch"
        )

        let result = service.sendReply(to: makeSession(bridgeTarget: mismatchedTarget), message: "continue")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "目标 Claude Code 会话已变化或不存在，请刷新后重试。")
    }

    func testValidateReplyRejectsUnavailableCapability() {
        let service = MockReplyBridgeService()
        let unavailableCapability = ReplyCapability(
            status: .unavailable,
            reason: "终端自动化权限未授权，请检查系统设置。",
            targetDescription: "Claude Code",
            channelStatus: "applescript-terminal"
        )

        let result = service.validateReply(for: makeSession(replyCapability: unavailableCapability), message: "continue")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "终端自动化权限未授权，请检查系统设置。")
    }

    func testValidateReplyRejectsEmptyWindowIdentifier() {
        let service = MockReplyBridgeService()
        let sessionWithEmptyWindowID = TaskSession(
            identity: SessionIdentity(
                cliKind: .claudeCode,
                terminalAppIdentifier: "com.apple.Terminal",
                windowIdentifier: "",
                commandLine: "",
                ttyIdentifier: "ttys031",
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 0)
            ),
            title: "Reply target",
            status: .replyAvailable,
            priority: 100,
            confidence: 0.92,
            summary: "Waiting for reply",
            bridgeTarget: BridgeTarget(
                cliKind: .claudeCode,
                sessionID: UUID(),
                terminalContext: "Claude Code · reply",
                channelType: "applescript-terminal",
                displayName: "Claude Code · reply"
            ),
            replyCapability: ReplyCapability(
                status: .available,
                reason: "Claude Code reply bridge is ready.",
                targetDescription: "Claude Code",
                channelStatus: "applescript-terminal"
            ),
            lastActiveAt: Date(timeIntervalSince1970: 0),
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            quickActions: [.continueExecution]
        )

        let result = service.validateReply(for: sessionWithEmptyWindowID, message: "continue")

        XCTAssertFalse(result.canSend)
        XCTAssertEqual(result.explanation, "目标 Claude Code 会话已变化或不存在，请刷新后重试。")
    }

    private func makeSession(
        cliKind: CLIKind = .claudeCode,
        terminalAppIdentifier: String = "com.apple.Terminal",
        bridgeTarget: BridgeTarget? = BridgeTarget(
            cliKind: .claudeCode,
            sessionID: UUID(),
            terminalContext: "Claude Code · reply",
            channelType: "applescript-terminal",
            displayName: "Claude Code · reply"
        ),
        replyCapability: ReplyCapability = ReplyCapability(
            status: .available,
            reason: "Claude Code reply bridge is ready.",
            targetDescription: "Claude Code",
            channelStatus: "applescript-terminal"
        )
    ) -> TaskSession {
        TaskSession(
            identity: SessionIdentity(
                cliKind: cliKind,
                terminalAppIdentifier: terminalAppIdentifier,
                windowIdentifier: "Claude Code · reply",
                commandLine: "",
                ttyIdentifier: "ttys031",
                startedAt: Date(timeIntervalSince1970: 0),
                lastSeenAt: Date(timeIntervalSince1970: 0)
            ),
            title: "Reply target",
            status: .replyAvailable,
            priority: 100,
            confidence: 0.92,
            summary: "Waiting for reply",
            bridgeTarget: bridgeTarget,
            replyCapability: replyCapability,
            lastActiveAt: Date(timeIntervalSince1970: 0),
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            quickActions: [.continueExecution]
        )
    }
}
