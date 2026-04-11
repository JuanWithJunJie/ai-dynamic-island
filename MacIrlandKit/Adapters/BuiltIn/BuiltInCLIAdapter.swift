import Foundation

public struct BuiltInCLIAdapter: CLIAdapter {
    public let cliKind: CLIKind
    public let commandTokens: [String]
    public let supportedQuickActions: [ReplyActionType]

    public init(cliKind: CLIKind, commandTokens: [String]) {
        self.cliKind = cliKind
        self.commandTokens = commandTokens
        self.supportedQuickActions = [.continueExecution, .retry, .explainReason, .stop, .supplementInfo, .customText]
    }

    public var replyCapability: ReplyCapability {
        ReplyCapability(
            status: .manualConfirmationRequired,
            reason: "该适配器不支持固定会话级能力，请以会话实时能力为准。",
            targetDescription: cliKind.displayName,
            channelStatus: "dynamic"
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
            windowIdentifier: event.snapshot.fullWindowName.isEmpty
                ? event.snapshot.windowTitle
                : event.snapshot.fullWindowName,
            commandLine: event.snapshot.commandLine,
            ttyIdentifier: event.snapshot.ttyIdentifier,
            startedAt: event.timestamp.addingTimeInterval(-300),
            lastSeenAt: event.timestamp
        )

        let transcriptWasEmpty = event.transcript.isEmpty
        let judgement = judgement(
            for: transcriptWasEmpty ? event.snippet : event.transcript,
            transcriptWasEmpty: transcriptWasEmpty,
            windowTitle: event.snapshot.windowTitle
        )
        let sessionStatus = judgement.status
        let target = BridgeTarget(
            cliKind: cliKind,
            sessionID: identity.id,
            terminalContext: event.snapshot.windowTitle,
            channelType: replyChannelType(for: event.snapshot.terminalAppIdentifier),
            displayName: "\(cliKind.displayName) · \(event.snapshot.windowTitle)"
        )
        let replyCapability = replyCapability(for: event.snapshot)
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
        let identitySeed: String
        if let ttyIdentifier = event.snapshot.ttyIdentifier, ttyIdentifier.isEmpty == false {
            // tty is the most stable live-session identifier across refreshes.
            // Window title and command line often drift while the same Claude session
            // is still running, which would otherwise create a new TaskSession.ID
            // every tick and replay state-transition cues.
            identitySeed = [
                cliKind.rawValue,
                event.snapshot.terminalAppIdentifier,
                ttyIdentifier
            ].joined(separator: "|")
        } else {
            identitySeed = [
                cliKind.rawValue,
                event.snapshot.terminalAppIdentifier,
                event.snapshot.windowTitle,
                event.snapshot.commandLine
            ].joined(separator: "|")
        }

        return UUID(uuidString: uuidString(from: identitySeed)) ?? UUID()
    }

    private func uuidString(from seed: String) -> String {
        // Use full-seed hashing so that any difference in the seed (including
        // different ttyIdentifier, windowTitle, or commandLine) produces a
        // different UUID. The previous implementation used `bytes[index % n]`
        // which only cycled through the first n bytes, causing all seeds with
        // the same prefix (e.g., all claudeCode sessions starting with
        // "claudeCode|com.apple.Terminal|...") to collide.
        var hash: UInt64 = 0
        for (index, scalar) in seed.unicodeScalars.enumerated() {
            let byte = UInt8(scalar.value & 0xFF)
            hash = hash &+ (UInt64(byte) &+ UInt64(index &* 31)) &<< (index % 8)
            if index % 3 == 0 { hash ^= hash >> 17 }
            if index % 5 == 0 { hash = hash &* 31 &+ 1 }
        }
        let hashBytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            uuidBytes[i] = hashBytes[i] ^ UInt8(i &* 17 &+ 5)
            uuidBytes[8 + i] = hashBytes[i] ^ UInt8(i &* 13 &+ 7)
        }
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        return String(
            format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ).lowercased()
    }

    private static func title(for event: RawCLIEvent) -> String {
        let prefix = event.snippet.split(separator: "\n").first.map(String.init) ?? event.snippet
        return prefix.isEmpty ? "未命名任务" : String(prefix.prefix(48))
    }

    private func judgement(for snippet: String, transcriptWasEmpty: Bool = false, windowTitle: String = "") -> ClaudeStatusJudgement {
        if cliKind == .claudeCode {
            // When transcript is empty due to Terminal/iTerm2 privacy protection,
            // we see nothing meaningful in snippet either. In that case, treat as
            // completed since we can't observe any running state.
            // But if snippet contains actual text (like "Anything else?"),
            // that text IS the signal and must be passed to the judge.
            if transcriptWasEmpty {
                let trimmed = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                // If snippet matches the pre-formatted output of snippet(for: ...),
                // it is already a status description produced by the observation
                // pipeline. Re-judging it through judge() would create a circular
                // feedback loop (the snippet format is derived from the status, and
                // judge() would re-derive the same status from the snippet format).
                // Extract the status directly from the snippet prefix instead.
                if let status = Self.statusFromSnippetFormat(trimmed) {
                    return ClaudeStatusJudgement(
                        status: status,
                        confidence: 0.88,
                        matchedSignals: 1,
                        dominantReason: "pre-formatted snippet, status extracted from prefix"
                    )
                }
                if trimmed.isEmpty || trimmed == "❯" || trimmed == "❯ " {
                    return ClaudeStatusJudgement(
                        status: .completed,
                        confidence: 0.8,
                        matchedSignals: 1,
                        dominantReason: "empty transcript with privacy protection"
                    )
                }
            }
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

    private func replyCapability(for snapshot: TerminalObservationSnapshot) -> ReplyCapability {
        guard cliKind == .claudeCode else {
            return ReplyCapability(
                status: .manualConfirmationRequired,
                reason: "当前仅 Claude Code 接入真实 reply bridge。",
                targetDescription: cliKind.displayName,
                channelStatus: "unsupported-cli"
            )
        }

        switch snapshot.terminalAppIdentifier {
        case "com.apple.Terminal":
            return ReplyCapability(
                status: .available,
                reason: "已接入真实 reply bridge，可直接发送到 Claude Code 终端会话。",
                targetDescription: cliKind.displayName,
                channelStatus: "applescript-terminal"
            )
        case "com.googlecode.iterm2":
            return ReplyCapability(
                status: .available,
                reason: "已接入真实 reply bridge，可直接发送到 Claude Code 终端会话。",
                targetDescription: cliKind.displayName,
                channelStatus: "applescript-iterm"
            )
        default:
            return ReplyCapability(
                status: .manualConfirmationRequired,
                reason: "当前仅支持通过 Terminal 或 iTerm 向 Claude Code 会话发送回复。",
                targetDescription: cliKind.displayName,
                channelStatus: "unsupported-terminal"
            )
        }
    }

    /// Extracts TaskStatus from the pre-formatted snippet produced by snippet(for: ...).
    /// These snippets have the form "StatusText in Claude Code terminal session: title".
    /// Returns nil if the snippet does not match this format.
    private static func statusFromSnippetFormat(_ snippet: String) -> TaskStatus? {
        let lowercased = snippet.lowercased()
        if lowercased.hasPrefix("completed ") { return .completed }
        if lowercased.hasPrefix("failed ") { return .failed }
        if lowercased.hasPrefix("alert in ") { return .alert }
        if lowercased.hasPrefix("waiting for input in ") { return .waitingInput }
        if lowercased.hasPrefix("context lost in ") { return .contextLost }
        return nil
    }

    private func replyChannelType(for terminalAppIdentifier: String) -> String {
        guard cliKind == .claudeCode else {
            return "unsupported-cli"
        }

        switch terminalAppIdentifier {
        case "com.apple.Terminal":
            return "applescript-terminal"
        case "com.googlecode.iterm2":
            return "applescript-iterm"
        default:
            return "unsupported-terminal"
        }
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
        if lowercased.contains("waiting for input") || lowercased.contains("need user input") || lowercased.contains("please confirm") || lowercased.contains("press enter") || lowercased.contains("press return") || lowercased.contains("y/n") || lowercased.contains("yes/no") || lowercased.contains("let me know") || lowercased.contains("tell me if") || lowercased.contains("what's next") || lowercased.contains("next step") || lowercased.contains("your turn") || lowercased.contains("ready for your") || lowercased.contains("anything else") || lowercased.contains("what else") || lowercased.contains("need anything else") || lowercased.contains("还需要什么") || lowercased.contains("还有什么需要") || lowercased.contains("do you want me to") {
            return .waitingInput
        }
        if lowercased.contains("reply") || lowercased.contains("respond") || lowercased.contains("if you want") || lowercased.contains("if you'd") || lowercased.contains("i can continue") || lowercased.contains("when you're ready") || lowercased.contains("feel free to ask") || lowercased.contains("just let me know") {
            return .replyAvailable
        }
        if lowercased.hasPrefix("completed ") || lowercased.contains("task complete") || lowercased.contains("successfully completed") || lowercased.contains("completed successfully") || lowercased.contains("all set") || lowercased.contains("finished generating") || lowercased.contains("finished successfully") || lowercased.contains("i'm done") || lowercased.contains("i am done") || lowercased.contains("that's all") || lowercased.contains("wrapping up") || lowercased.contains("created file:") || lowercased.contains("created directory:") {
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
