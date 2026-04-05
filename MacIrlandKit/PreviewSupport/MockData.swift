import Foundation

public enum MockData {
    public static var sampleEvents: [RawCLIEvent] {
        [
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Need user input: please confirm whether to proceed with the refactor.",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · refactor flow",
                    commandLine: "claude code",
                    ttyIdentifier: "ttys001"
                )
            ),
            RawCLIEvent(
                cliKind: .codex,
                snippet: "Running tests for sidebar redesign…",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    windowTitle: "Codex · sidebar redesign",
                    commandLine: "codex --task sidebar",
                    ttyIdentifier: "ttys002"
                )
            ),
            RawCLIEvent(
                cliKind: .gemini,
                snippet: "Completed draft summary for release checklist.",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Gemini CLI · release",
                    commandLine: "gemini summarize",
                    ttyIdentifier: "ttys003"
                )
            )
        ]
    }

    public static var sampleFallbackSession: TaskSession {
        let now = Date.now
        let identity = SessionIdentity(
            cliKind: .unknown,
            terminalAppIdentifier: "system",
            windowIdentifier: "No active task",
            ttyIdentifier: nil,
            startedAt: now,
            lastSeenAt: now
        )

        return TaskSession(
            identity: identity,
            title: "等待新的 AI CLI 任务",
            status: .discovered,
            priority: 0,
            confidence: 0.4,
            summary: "当前没有检测到可聚合的 CLI 会话。",
            bridgeTarget: nil,
            replyCapability: ReplyCapability(
                status: .unavailable,
                reason: "暂无可回复会话。",
                targetDescription: "Unknown CLI",
                channelStatus: "idle"
            ),
            lastActiveAt: now,
            evidence: [],
            recentEvents: [],
            recentMessages: [],
            quickActions: []
        )
    }
}
