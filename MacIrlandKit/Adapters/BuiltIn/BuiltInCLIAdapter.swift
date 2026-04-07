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
        let commandLine = snapshot.commandLine.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let windowTitle = snapshot.windowTitle.lowercased()

        if cliKind == .claudeCode {
            return ClaudeSnapshotMatcher.recognizes(snapshot: snapshot)
        }

        let haystack = "\(windowTitle) \(commandLine)"
        return commandTokens.contains(where: { haystack.contains($0.lowercased()) })
    }

    public func buildSession(from event: RawCLIEvent) -> TaskSession? {
        guard event.cliKind == cliKind || recognizes(snapshot: event.snapshot) else {
            return nil
        }

        let sessionID = stableSessionID(for: event)
        let identity = SessionIdentity(
            id: sessionID,
            cliKind: cliKind,
            terminalAppIdentifier: event.snapshot.terminalAppIdentifier,
            windowIdentifier: event.snapshot.windowTitle,
            ttyIdentifier: event.snapshot.ttyIdentifier,
            startedAt: event.timestamp.addingTimeInterval(-300),
            lastSeenAt: event.timestamp
        )

        let judgement = judgement(for: event.snippet)
        let sessionStatus = judgement.status
        let target = BridgeTarget(
            cliKind: cliKind,
            sessionID: identity.id,
            terminalContext: event.snapshot.windowTitle,
            channelType: "mock-terminal",
            displayName: "\(cliKind.displayName) · \(event.snapshot.windowTitle)"
        )
        let initialHistoryEntry = SessionHistoryEntry(
            timestamp: event.timestamp,
            kind: Self.historyKind(for: sessionStatus),
            title: sessionStatus.label,
            detail: event.snippet,
            relatedStatus: sessionStatus
        )

        return TaskSession(
            id: sessionID,
            identity: identity,
            title: Self.title(for: event),
            status: sessionStatus,
            priority: Self.priority(for: sessionStatus),
            confidence: judgement.confidence,
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
                SessionEvent(kind: Self.eventKind(for: sessionStatus), message: event.snippet)
            ],
            recentMessages: [
                MessageSnippet(
                    kind: sessionStatus == .alert ? .error : .assistant,
                    text: event.snippet,
                    isHighlighted: sessionStatus.needsAttention,
                    isError: sessionStatus == .alert || sessionStatus == .failed
                )
            ],
            historyEntries: [initialHistoryEntry],
            quickActions: supportedQuickActions
        )
    }

    private func stableSessionID(for event: RawCLIEvent) -> UUID {
        let identitySeed = [
            cliKind.rawValue,
            event.snapshot.terminalAppIdentifier,
            event.snapshot.windowTitle,
            event.snapshot.commandLine,
            event.snapshot.ttyIdentifier ?? "no-tty"
        ].joined(separator: "|")

        return UUID(uuidString: uuidString(from: identitySeed)) ?? UUID()
    }

    private func uuidString(from seed: String) -> String {
        let bytes = Array(seed.utf8)
        guard !bytes.isEmpty else {
            return "00000000-0000-4000-8000-000000000000"
        }

        var uuidBytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<16 {
            let byte = bytes[index % bytes.count]
            let mixed = UInt8((index * 31) & 0xFF)
            uuidBytes[index] = byte ^ mixed
        }

        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        return String(
            format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5],
            uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9],
            uuidBytes[10], uuidBytes[11], uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ).lowercased()
    }

    private static func title(for event: RawCLIEvent) -> String {
        let prefix = event.snippet.split(separator: "\n").first.map(String.init) ?? event.snippet
        return prefix.isEmpty ? "未命名任务" : String(prefix.prefix(48))
    }

    private func judgement(for snippet: String) -> ClaudeStatusJudgement {
        if cliKind == .claudeCode {
            return ClaudeStatusJudge.judge(transcript: snippet)
        }

        let status = Self.status(for: snippet)
        return ClaudeStatusJudgement(
            status: status,
            confidence: Self.confidence(for: status),
            matchedSignals: 1,
            dominantReason: "adapter fallback"
        )
    }

    private static func status(for snippet: String) -> TaskStatus {
        let lowercased = snippet.lowercased()
        if lowercased.contains("context lost") || lowercased.contains("session expired") {
            return .contextLost
        }
        if lowercased.contains("failed") || lowercased.contains("fatal error") || lowercased.contains("fatal:") || lowercased.contains("error:") {
            return .failed
        }
        if lowercased.contains("alert") || lowercased.contains("warning:") || lowercased.contains("rate limit") || lowercased.contains("retrying") || lowercased.contains("interrupted") || lowercased.contains("throttled") {
            return .alert
        }
        if lowercased.contains("waiting for input") || lowercased.contains("need user input") || lowercased.contains("please confirm") || lowercased.contains("press enter") || lowercased.contains("press return") || lowercased.contains("y/n") || lowercased.contains("yes/no") {
            return .waitingInput
        }
        if lowercased.contains("reply") || lowercased.contains("respond") {
            return .replyAvailable
        }
        if lowercased.hasPrefix("completed ") || lowercased.contains("task complete") || lowercased.contains("successfully completed") || lowercased.contains("completed successfully") || lowercased.contains("all set") || lowercased.contains("finished generating") || lowercased.contains("finished successfully") {
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
        case .failed:
            return 0.82
        case .contextLost:
            return 0.74
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

    private static func historyKind(for status: TaskStatus) -> SessionHistoryKind {
        switch status {
        case .discovered, .recognizing:
            return .phaseDiscovered
        case .running:
            return .phaseRunning
        case .waitingInput:
            return .phaseWaitingInput
        case .replyAvailable:
            return .phaseReplyAvailable
        case .alert:
            return .phaseAlert
        case .completed:
            return .phaseCompleted
        case .failed:
            return .phaseFailed
        case .contextLost:
            return .phaseContextLost
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
}

public extension BuiltInCLIAdapter {
    static let codex = BuiltInCLIAdapter(cliKind: .codex, commandTokens: ["codex"])
    static let claudeCode = BuiltInCLIAdapter(cliKind: .claudeCode, commandTokens: ["claude", "claude code"])
    static let gemini = BuiltInCLIAdapter(cliKind: .gemini, commandTokens: ["gemini"])
}
