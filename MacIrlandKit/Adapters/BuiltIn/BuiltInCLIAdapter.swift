import Foundation

public struct BuiltInCLIAdapter: CLIAdapter {
    public let cliKind: CLIKind
    public let commandTokens: [String]
    public let supportedQuickActions: [ReplyActionType]
    public let replyCapability: ReplyCapability

    public init(cliKind: CLIKind, commandTokens: [String]) {
        self.cliKind = cliKind
        self.commandTokens = commandTokens
        self.supportedQuickActions = [.continueExecution, .retry, .explainReason, .stop, .supplementInfo, .customText]
        self.replyCapability = ReplyCapability(
            status: .manualConfirmationRequired,
            reason: "MVP 骨架阶段尚未接入真实桥接通道。",
            targetDescription: cliKind.displayName,
            channelStatus: "mock"
        )
    }

    public func recognizes(snapshot: TerminalObservationSnapshot) -> Bool {
        let haystack = "\(snapshot.windowTitle.lowercased()) \(snapshot.commandLine.lowercased())"
        return commandTokens.contains(where: { haystack.contains($0.lowercased()) })
    }

    public func buildSession(from event: RawCLIEvent) -> TaskSession? {
        guard recognizes(snapshot: event.snapshot) else {
            return nil
        }

        let identity = SessionIdentity(
            cliKind: cliKind,
            terminalAppIdentifier: event.snapshot.terminalAppIdentifier,
            windowIdentifier: event.snapshot.windowTitle,
            ttyIdentifier: event.snapshot.ttyIdentifier,
            startedAt: event.timestamp.addingTimeInterval(-300),
            lastSeenAt: event.timestamp
        )

        let status = Self.status(for: event.snippet)
        let target = BridgeTarget(
            cliKind: cliKind,
            sessionID: identity.id,
            terminalContext: event.snapshot.windowTitle,
            channelType: "mock-terminal",
            displayName: "\(cliKind.displayName) · \(event.snapshot.windowTitle)"
        )

        return TaskSession(
            identity: identity,
            title: Self.title(for: event),
            status: status,
            priority: Self.priority(for: status),
            confidence: Self.confidence(for: status),
            summary: event.snippet,
            bridgeTarget: target,
            replyCapability: replyCapability,
            lastActiveAt: event.timestamp,
            evidence: [
                EvidenceItem(
                    sourceType: .adapter,
                    summary: "命中 \(cliKind.displayName) 适配器规则",
                    rawSnippet: event.snippet,
                    weight: 0.8
                )
            ],
            recentEvents: [
                SessionEvent(kind: Self.eventKind(for: status), message: event.snippet)
            ],
            recentMessages: [
                MessageSnippet(
                    kind: status == .alert ? .error : .assistant,
                    text: event.snippet,
                    isHighlighted: status.needsAttention,
                    isError: status == .alert || status == .failed
                )
            ],
            quickActions: supportedQuickActions,
            recoverySuggestion: Self.recoverySuggestion(for: status)
        )
    }

    private static func title(for event: RawCLIEvent) -> String {
        let prefix = event.snippet.split(separator: "\n").first.map(String.init) ?? event.snippet
        return prefix.isEmpty ? "未命名任务" : String(prefix.prefix(48))
    }

    private static func status(for snippet: String) -> TaskStatus {
        let lowercased = snippet.lowercased()
        if lowercased.contains("waiting") || lowercased.contains("input") || lowercased.contains("confirm") {
            return .waitingInput
        }
        if lowercased.contains("reply") || lowercased.contains("respond") {
            return .replyAvailable
        }
        if lowercased.contains("error") || lowercased.contains("failed") || lowercased.contains("exception") {
            return .alert
        }
        if lowercased.contains("done") || lowercased.contains("completed") || lowercased.contains("finished") {
            return .completed
        }
        return .running
    }

    private static func confidence(for status: TaskStatus) -> Double {
        switch status {
        case .replyAvailable:
            return 0.86
        case .waitingInput, .alert, .completed:
            return 0.78
        case .running:
            return 0.7
        default:
            return 0.55
        }
    }

    private static func priority(for status: TaskStatus) -> Int {
        switch status {
        case .replyAvailable:
            return 100
        case .waitingInput:
            return 95
        case .alert, .failed:
            return 90
        case .running:
            return 70
        case .completed:
            return 40
        case .contextLost:
            return 30
        case .discovered, .recognizing:
            return 20
        }
    }

    private static func eventKind(for status: TaskStatus) -> SessionEventKind {
        switch status {
        case .waitingInput:
            return .waitingForInput
        case .replyAvailable:
            return .replyCapabilityChanged
        case .alert:
            return .warning
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .contextLost:
            return .contextLost
        default:
            return .started
        }
    }

    private static func recoverySuggestion(for status: TaskStatus) -> String? {
        switch status {
        case .waitingInput:
            return "补充必要信息或确认下一步，任务即可继续。"
        case .replyAvailable:
            return "检查建议回复后可直接回到对应 CLI 会话继续推进。"
        case .alert, .failed:
            return "建议先查看错误片段，再选择重试或补充上下文。"
        case .completed:
            return "任务已完成，可整理结果摘要并决定是否继续下一步。"
        case .contextLost:
            return "上下文已丢失，建议回到原终端重新建立会话。"
        case .running, .discovered, .recognizing:
            return nil
        }
    }
}

public extension BuiltInCLIAdapter {
    static let codex = BuiltInCLIAdapter(cliKind: .codex, commandTokens: ["codex"])
    static let claudeCode = BuiltInCLIAdapter(cliKind: .claudeCode, commandTokens: ["claude", "claude code"])
    static let gemini = BuiltInCLIAdapter(cliKind: .gemini, commandTokens: ["gemini"])
}
