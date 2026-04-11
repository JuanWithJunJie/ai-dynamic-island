import AppKit
import Foundation

public struct ObservationSnapshotResult: Hashable, Codable, Sendable {
    public let events: [RawCLIEvent]
    public let diagnostics: ObservationDiagnostics

    public init(events: [RawCLIEvent], diagnostics: ObservationDiagnostics) {
        self.events = events
        self.diagnostics = diagnostics
    }
}

public protocol ObservationProviding: Sendable {
    func latestSnapshot() -> ObservationSnapshotResult
}

public extension ObservationProviding {
    func latestEvents() -> [RawCLIEvent] {
        latestSnapshot().events
    }

    func latestDiagnostics() -> ObservationDiagnostics {
        latestSnapshot().diagnostics
    }
}

struct ClaudeStatusJudgement: Sendable {
    let status: TaskStatus
    let confidence: Double
    let matchedSignals: Int
    let dominantReason: String
}

enum ClaudeTranscriptNormalizer {
    static func normalize(_ transcript: String) -> String {
        guard transcript.isEmpty == false else {
            return ""
        }

        let unifiedNewlines = transcript
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let withoutANSI = strippingANSIEscapes(from: unifiedNewlines)
        let withoutControls = String(
            withoutANSI.unicodeScalars.filter { scalar in
                switch scalar.value {
                case 0x09, 0x0A:
                    return true
                case 0x20...0x7E, 0xA0...0x10FFFF:
                    return true
                default:
                    return false
                }
            }
        )

        let normalizedLines = withoutControls
            .components(separatedBy: .newlines)
            .map(normalizeLine(_:))
            .filter { line in
                line.isEmpty == false && isDecorativeLine(line) == false
            }

        return normalizedLines.joined(separator: "\n")
    }

    static func normalizedTail(from transcript: String, maxLength: Int = 2400, maxLines: Int = 18) -> String {
        let normalized = normalize(transcript)
        guard normalized.isEmpty == false else {
            return ""
        }

        let lines = normalized
            .components(separatedBy: .newlines)
            .filter { $0.isEmpty == false }
        let recentLines = Array(lines.suffix(maxLines))
        let recentText = recentLines.joined(separator: "\n")

        guard recentText.count > maxLength else {
            return recentText
        }
        return String(recentText.suffix(maxLength))
    }

    static func normalizedHead(from transcript: String, maxLength: Int = 2000) -> String {
        let normalized = normalize(transcript)
        guard normalized.count > maxLength else {
            return normalized
        }
        return String(normalized.prefix(maxLength))
    }

    static func preview(for transcript: String, maxLength: Int = 180) -> String {
        let normalized = normalize(transcript).trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            return "(空 normalized transcript)"
        }

        if normalized.count > maxLength {
            return String(normalized.prefix(maxLength)) + "…"
        }
        return normalized
    }

    private static func normalizeLine(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"[ \t]+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isDecorativeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "❯" || trimmed == "claude>" || trimmed.hasSuffix("claude>") {
            return false
        }

        let hasMeaningfulContent = line.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            CharacterSet(charactersIn: "\u{4E00}" ... "\u{9FFF}").contains(scalar)
        }
        return hasMeaningfulContent == false
    }

    private static func strippingANSIEscapes(from text: String) -> String {
        let patterns = [
            #"\u{001B}\[[0-?]*[ -/]*[@-~]"#,
            #"\u{001B}\][^\u{0007}]*\u{0007}"#
        ]

        return patterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
    }
}

enum ClaudeStatusJudge {
    static func judge(transcript: String) -> ClaudeStatusJudgement {
        let normalizedTail = ClaudeTranscriptNormalizer
            .normalizedTail(from: transcript, maxLength: 2400)
        let lowercased = normalizedTail.lowercased()
        guard !lowercased.isEmpty else {
            return ClaudeStatusJudgement(status: .running, confidence: 0.62, matchedSignals: 0, dominantReason: "empty transcript")
        }

        if let normalized = normalizedSessionSnippetJudgement(for: lowercased) {
            return normalized
        }

        let contextLostScore = score(
            in: lowercased,
            strongSignals: [
                "context lost",
                "lost context",
                "session expired",
                "conversation not found",
                "context window exceeded"
            ],
            mediumSignals: [
                "cannot continue",
                "can't continue",
                "unable to continue"
            ],
            weakSignals: [
                "context window"
            ],
            antiSignals: []
        )

        let failedScore = score(
            in: lowercased,
            strongSignals: [
                "permission denied",
                "fatal error",
                "fatal:",
                "traceback",
                "exception"
            ],
            mediumSignals: [
                "error:",
                "non-zero exit",
                "unable to",
                "failed to",
                "could not"
            ],
            weakSignals: [
                "error while",
                "failed"
            ],
            antiSignals: []
        )

        let waitingInputScore = score(
            in: lowercased,
            strongSignals: [
                "waiting for input",
                "need user input",
                "awaiting your confirmation",
                "what's next",
                "your turn",
                "ready for your next",
                "what would you like",
                "let me know if",
                "tell me if you want",
                "anything else",
                "what else",
                "need anything else",
                "if you need anything",
                "如果你愿意，我可以继续",
                "如果你愿意我可以继续",
                "如果你需要的话告诉我",
                "需要我继续的话",
                "接下来你想让我",
                "有什么可以帮你",
                "还需要什么",
                "还有什么需要",
                "当前任务完成，请局座指示",
                "请局座指示"
            ],
            mediumSignals: [
                "please confirm",
                "press enter",
                "press return",
                "approve?",
                "confirm to continue",
                "let me know",
                "tell me if",
                "next step",
                "ready for your",
                "tell me what",
                "you want me to",
                "do you want me to",
                "如果你愿意",
                "如果需要的话",
                "告诉我接下来",
                "下一步想让我",
                "当前任务完成"
            ],
            weakSignals: [
                "press any key",
                "enter to continue",
                "type y or n",
                "输入 y 或 n"
            ],
            antiSignals: [
                "i can confirm",
                "can confirm",
                "confirmed that",
                "confirmation message",
                "y/n:",
                "yes/no:",
                "i'm done",
                "all done",
                "done!",
                "finished",
                "completed",
                "task completed",
                "exited",
                "goodbye",
                "shell exited",
                "process exited",
                "that's all",
                "all tasks completed"
            ]
        )

        let replyAvailableScore = score(
            in: lowercased,
            strongSignals: [
                "draft reply",
                "reply available",
                "if you want",
                "feel free to ask",
                "if you'd like",
                "if you need",
                "我可以帮",
                "还有什么我可以帮",
                "如果你愿意，我可以",
                "如果你愿意我可以",
                "需要的话我可以",
                "还有什么要",
                "do you have any"
            ],
            mediumSignals: [
                "respond to continue",
                "reply to continue",
                "waiting for reply",
                "i can continue",
                "i'm ready to continue",
                "i'm prepared",
                "i am prepared",
                "ready to move on",
                "when you're ready",
                "ready",
                "just let me know"
            ],
            weakSignals: [
                "reply",
                "respond"
            ],
            antiSignals: [
                "reply capability",
                "response time",
                "i'm done",
                "all done",
                "done!",
                "finished",
                "completed",
                "task completed",
                "exited",
                "goodbye",
                "shell exited",
                "process exited",
                "that's all"
            ]
        )

        let alertScore = score(
            in: lowercased,
            strongSignals: [
                "warning:",
                "rate limit",
                "throttled",
                "network unstable"
            ],
            mediumSignals: [
                "retrying",
                "interrupted",
                "temporary issue"
            ],
            weakSignals: [
                "warning",
                "backoff"
            ],
            antiSignals: [
                "network model",
                "warning sign"
            ]
        )

        let completedScore = score(
            in: lowercased,
            strongSignals: [
                "successfully completed",
                "completed successfully",
                "finished successfully",
                "finished generating",
                "i'm done",
                "all done",
                "done! that's all",
                "done!",
                "all set",
                "that's all for now",
                "that's everything",
                "you're all set",
                "ready for the next one",
                "created file:",
                "created directory:",
                "done! created",
                "task completed",
                "all tasks completed",
                "tasks completed",
                "completed tasks",
                "no more tasks",
                "finished all",
                "exited",
                "goodbye",
                "process exited",
                "shell exited"
            ],
            mediumSignals: [
                "done successfully",
                "i am done",
                "wrapping up",
                "all done.",
                "done with it",
                "done with this",
                "文件已创建",
                "已完成",
                "generation complete",
                "generation complete.",
                "✓",
                "jobs completed",
                "tasks finished"
            ],
            weakSignals: [
                "completed",
                "finished",
                "done"
            ],
            antiSignals: [
                "not done",
                "not completed",
                "not finished",
                "unfinished",
                "we are not done",
                "can't be done",
                "still running",
                "in progress"
            ]
        )

        let hasActiveProgressSignal =
            lowercased.contains("thundering") ||
            lowercased.contains("(thinking)") ||
            lowercased.contains("thinking through") ||
            lowercased.contains("working through") ||
            lowercased.contains("analyzing") ||
            lowercased.contains("implementing") ||
            lowercased.contains("processing current") ||
            lowercased.contains("processing...")

        if let promptReturnJudgement = promptReturnJudgement(
            normalizedTail: normalizedTail,
            waitingInputScore: waitingInputScore,
            replyAvailableScore: replyAvailableScore,
            completedScore: completedScore
        ) {
            return promptReturnJudgement
        }

        // Special case: if completed has a strong signal AND waitingInput does NOT have a strong signal,
        // completed should win. This handles "All done! What's next?" where both completion and
        // "what's next" signals fire, but completion should win because waitingInput's
        // "what's next" is just conversational after task completion.
        // However, if waitingInput also has a strong signal (e.g., "Anything else?"), let the
        // candidates loop decide which is more dominant.
        if completedScore.hasStrongSignal && !waitingInputScore.hasStrongSignal && qualifies(signal: completedScore, for: .completed) {
            return ClaudeStatusJudgement(
                status: .completed,
                confidence: confidence(for: .completed, signal: completedScore),
                matchedSignals: completedScore.matchedSignals,
                dominantReason: completedScore.dominantReason.isEmpty ? "strong completion signal" : completedScore.dominantReason
            )
        }

        if hasActiveProgressSignal {
            return ClaudeStatusJudgement(
                status: .running,
                confidence: 0.8,
                matchedSignals: 1,
                dominantReason: "active progress signal"
            )
        }

        let candidates: [(TaskStatus, SignalScore)] = [
            (.contextLost, contextLostScore),
            (.failed, failedScore),
            (.waitingInput, waitingInputScore),
            (.alert, alertScore),
            (.completed, completedScore),
            (.replyAvailable, replyAvailableScore)
        ]

        for (status, signal) in candidates {
            guard qualifies(signal: signal, for: status) else {
                continue
            }

            return ClaudeStatusJudgement(
                status: status,
                confidence: confidence(for: status, signal: signal),
                matchedSignals: signal.matchedSignals,
                dominantReason: signal.dominantReason
            )
        }

        return ClaudeStatusJudgement(status: .running, confidence: 0.66, matchedSignals: 0, dominantReason: "no decisive signals")
    }

    private struct SignalScore {
        let total: Int
        let matchedSignals: Int
        let dominantReason: String
        let hasStrongSignal: Bool
        let hasMediumSignal: Bool
    }

    private static func score(
        in text: String,
        strongSignals: [String],
        mediumSignals: [String],
        weakSignals: [String],
        antiSignals: [String]
    ) -> SignalScore {
        var total = 0
        var matchedSignals = 0
        var dominantReason = ""
        var dominantWeight = Int.min
        var hasStrongSignal = false
        var hasMediumSignal = false

        func apply(signals: [String], weight: Int, markStrong: Bool = false, markMedium: Bool = false) {
            for signal in signals where text.contains(signal) {
                total += weight
                matchedSignals += 1
                if weight > dominantWeight {
                    dominantWeight = weight
                    dominantReason = signal
                }
                if markStrong {
                    hasStrongSignal = true
                }
                if markMedium {
                    hasMediumSignal = true
                }
            }
        }

        apply(signals: strongSignals, weight: 4, markStrong: true)
        apply(signals: mediumSignals, weight: 2, markMedium: true)
        apply(signals: weakSignals, weight: 1)
        apply(signals: antiSignals, weight: -3)

        if matchedSignals >= 2 {
            total += 1
        }
        if matchedSignals >= 3 {
            total += 1
        }

        return SignalScore(
            total: total,
            matchedSignals: matchedSignals,
            dominantReason: dominantReason.isEmpty ? "no dominant reason" : dominantReason,
            hasStrongSignal: hasStrongSignal,
            hasMediumSignal: hasMediumSignal
        )
    }

    private static func qualifies(signal: SignalScore, for status: TaskStatus) -> Bool {
        switch status {
        case .contextLost, .failed:
            return signal.hasStrongSignal || signal.total >= 4
        case .waitingInput, .replyAvailable, .alert, .completed:
            return signal.hasStrongSignal || signal.total >= 3 || (signal.hasMediumSignal && signal.matchedSignals >= 2)
        default:
            return false
        }
    }

    private static func normalizedSessionSnippetJudgement(for text: String) -> ClaudeStatusJudgement? {
        // These prefix checks were removed because they matched the output of
        // snippet(for:), creating circular feedback loops where a session's own
        // summary text re-triggered the same status. Real terminal session states
        // are correctly classified by the scoring system below.
        return nil
    }

    private static func promptReturnJudgement(
        normalizedTail: String,
        waitingInputScore: SignalScore,
        replyAvailableScore: SignalScore,
        completedScore: SignalScore
    ) -> ClaudeStatusJudgement? {
        let lines = normalizedTail
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last, isClaudePromptLine(lastLine) else {
            return nil
        }

        let contextLines = Array(lines.dropLast().suffix(4))
        let contextText = contextLines.joined(separator: "\n")
        let lowercasedContext = contextText.lowercased()

        let hasCompletionMarker =
            contextText.contains("✔") ||
            contextText.contains("✓") ||
            lowercasedContext.contains("已完成") ||
            lowercasedContext.contains("created file:") ||
            lowercasedContext.contains("created directory:") ||
            lowercasedContext.contains("all done") ||
            lowercasedContext.contains("done!") ||
            lowercasedContext.contains("finished successfully")

        let hasActiveProgress =
            lowercasedContext.contains("working through") ||
            lowercasedContext.contains("analyzing") ||
            lowercasedContext.contains("implementing") ||
            lowercasedContext.contains("processing") ||
            lowercasedContext.contains("still running") ||
            lowercasedContext.contains("in progress")

        guard !hasActiveProgress else {
            return nil
        }

        // Key distinction: if there's a completion marker AND a strong offer-to-continue signal,
        // treat as replyAvailable/waitingInput (Claude is offering to do more).
        // If there's a completion marker but no strong offer signal, treat as completed.
        let hasOfferSignal = waitingInputScore.hasStrongSignal || replyAvailableScore.hasStrongSignal

        if hasCompletionMarker {
            if hasOfferSignal && (qualifies(signal: waitingInputScore, for: .waitingInput) || qualifies(signal: replyAvailableScore, for: .replyAvailable)) {
                // Completion + strong offer → prefer the offer (replyAvailable/waitingInput)
                if waitingInputScore.hasStrongSignal && qualifies(signal: waitingInputScore, for: .waitingInput) {
                    return ClaudeStatusJudgement(
                        status: .waitingInput,
                        confidence: confidence(for: .waitingInput, signal: waitingInputScore),
                        matchedSignals: waitingInputScore.matchedSignals,
                        dominantReason: "prompt returned after waiting-input signal: \(waitingInputScore.dominantReason)"
                    )
                }
                if qualifies(signal: replyAvailableScore, for: .replyAvailable) {
                    return ClaudeStatusJudgement(
                        status: .replyAvailable,
                        confidence: confidence(for: .replyAvailable, signal: replyAvailableScore),
                        matchedSignals: replyAvailableScore.matchedSignals,
                        dominantReason: "prompt returned after reply-available signal: \(replyAvailableScore.dominantReason)"
                    )
                }
            }
            // Completion without strong offer → completed
            return ClaudeStatusJudgement(
                status: .completed,
                confidence: max(0.82, confidence(for: .completed, signal: completedScore)),
                matchedSignals: max(completedScore.matchedSignals, 1),
                dominantReason: "prompt returned after completion marker"
            )
        }

        if qualifies(signal: waitingInputScore, for: .waitingInput) {
            return ClaudeStatusJudgement(
                status: .waitingInput,
                confidence: confidence(for: .waitingInput, signal: waitingInputScore),
                matchedSignals: waitingInputScore.matchedSignals,
                dominantReason: "prompt returned after waiting-input signal: \(waitingInputScore.dominantReason)"
            )
        }

        if qualifies(signal: replyAvailableScore, for: .replyAvailable) {
            return ClaudeStatusJudgement(
                status: .replyAvailable,
                confidence: confidence(for: .replyAvailable, signal: replyAvailableScore),
                matchedSignals: replyAvailableScore.matchedSignals,
                dominantReason: "prompt returned after reply-available signal: \(replyAvailableScore.dominantReason)"
            )
        }

        return ClaudeStatusJudgement(
            status: .waitingInput,
            confidence: 0.74,
            matchedSignals: 1,
            dominantReason: "prompt returned without active progress"
        )
    }

    private static func isClaudePromptLine(_ line: String) -> Bool {
        let lowercased = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return lowercased == "claude>" ||
            lowercased.hasSuffix("claude>") ||
            lowercased == "❯" ||
            lowercased.hasPrefix("❯ ")
    }

    private static func confidence(for status: TaskStatus, signal: SignalScore) -> Double {
        let base: Double
        switch status {
        case .replyAvailable:
            base = 0.76
        case .waitingInput, .alert, .completed:
            base = 0.72
        case .failed:
            base = 0.8
        case .contextLost:
            base = 0.78
        default:
            base = 0.66
        }

        let bonus = min(Double(max(signal.total, 0)) * 0.03, 0.16)
        return min(base + bonus, 0.96)
    }
}

public struct MockObservationService: ObservationProviding {
    public init() {}

    public func latestSnapshot() -> ObservationSnapshotResult {
        ObservationSnapshotResult(
            events: MockData.sampleEvents,
            diagnostics: ObservationDiagnostics(readers: [], sessions: [])
        )
    }
}

public struct RealTerminalObservationService: ObservationProviding {
    private let terminalReaders: [any TerminalAppReading]

    public init() {
        self.terminalReaders = [
            AppleTerminalReader(),
            ITermReader()
        ]
    }

    init(terminalReaders: [any TerminalAppReading]) {
        self.terminalReaders = terminalReaders
    }

    public func latestSnapshot() -> ObservationSnapshotResult {
        let snapshot = latestObservationSnapshot()
        return ObservationSnapshotResult(events: snapshot.events, diagnostics: snapshot.diagnostics)
    }

    private func latestObservationSnapshot() -> ObservationSnapshot {
        var readerDiagnostics: [ObservationReaderDiagnostic] = []
        var sessionDiagnostics: [ObservationSessionDiagnostic] = []
        var events: [RawCLIEvent] = []

        for reader in terminalReaders {
            let readerResult = reader.fetchResult()
            var recognizedCount = 0

            for observation in readerResult.observations {
                let eventResult = Self.eventResult(from: observation)
                sessionDiagnostics.append(eventResult.diagnostic)
                if let event = eventResult.event {
                    recognizedCount += 1
                    events.append(event)
                }
            }

            readerDiagnostics.append(
                ObservationReaderDiagnostic(
                    id: readerResult.readerID,
                    readerName: readerResult.readerName,
                    terminalAppIdentifier: readerResult.terminalAppIdentifier,
                    isAppRunning: readerResult.isAppRunning,
                    fetchStatus: readerResult.fetchStatus,
                    observationCount: readerResult.observations.count,
                    recognizedEventCount: recognizedCount,
                    message: readerResult.message
                )
            )
        }

        return ObservationSnapshot(
            events: events,
            diagnostics: ObservationDiagnostics(
                readers: readerDiagnostics,
                sessions: sessionDiagnostics
            )
        )
    }

    private static func eventResult(from observation: ObservedTerminalSession) -> ObservationEventResult {
        guard let cliKind = recognizedCLIKind(for: observation) else {
            return ObservationEventResult(
                event: nil,
                diagnostic: ObservationSessionDiagnostic(
                    terminalAppIdentifier: observation.snapshot.terminalAppIdentifier,
                    windowTitle: observation.snapshot.windowTitle,
                    commandLine: observation.snapshot.commandLine,
                    ttyIdentifier: observation.snapshot.ttyIdentifier,
                    transcriptPreview: observation.transcriptPreview,
                    normalizedTranscriptPreview: observation.normalizedTranscriptPreview,
                    recognizedCLIKind: nil,
                    inferredStatus: nil,
                    decisionReason: "未命中 Claude Code 识别规则"
                )
            )
        }

        // Terminal.app can temporarily yield an empty transcript or incomplete process list
        // even while Claude is still active, so avoid forcing a completed state here.
        let transcriptEmpty = observation.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let judgement: ClaudeStatusJudgement
        if cliKind == .claudeCode,
           transcriptEmpty,
           let isBusy = observation.snapshot.isBusy {
            if isBusy {
                judgement = ClaudeStatusJudgement(
                    status: .running,
                    confidence: 0.78,
                    matchedSignals: 1,
                    dominantReason: "terminal busy signal with empty transcript"
                )
            } else {
                judgement = ClaudeStatusJudgement(
                    status: .waitingInput,
                    confidence: 0.8,
                    matchedSignals: 1,
                    dominantReason: "terminal idle signal with empty transcript"
                )
            }
        } else {
            judgement = ClaudeStatusJudge.judge(transcript: observation.transcript)
        }
        let status = judgement.status
        let event = RawCLIEvent(
            cliKind: cliKind,
            snippet: snippet(for: observation.snapshot, cliKind: cliKind, status: status),
            transcript: observation.transcript,
            snapshot: observation.snapshot
        )

        return ObservationEventResult(
            event: event,
            diagnostic: ObservationSessionDiagnostic(
                terminalAppIdentifier: observation.snapshot.terminalAppIdentifier,
                windowTitle: observation.snapshot.windowTitle,
                commandLine: observation.snapshot.commandLine,
                ttyIdentifier: observation.snapshot.ttyIdentifier,
                transcriptPreview: observation.transcriptPreview,
                normalizedTranscriptPreview: observation.normalizedTranscriptPreview,
                recognizedCLIKind: cliKind,
                inferredStatus: status,
                decisionReason: "已识别并转成 \(cliKind.displayName) 事件 · \(judgement.dominantReason)",
                matchedSignals: judgement.matchedSignals,
                confidence: judgement.confidence,
                normalizedTail: observation.normalizedTail
            )
        )
    }

    private static func recognizedCLIKind(for observation: ObservedTerminalSession) -> CLIKind? {
        if ClaudeSnapshotMatcher.recognizes(snapshot: observation.snapshot, transcript: observation.normalizedTranscript) {
            return .claudeCode
        }

        return nil
    }

    private static func snippet(for snapshot: TerminalObservationSnapshot, cliKind: CLIKind, status: TaskStatus) -> String {
        let title = snapshot.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionTitle = title.isEmpty ? cliKind.displayName : title

        switch status {
        case .contextLost:
            return "Context lost in \(cliKind.displayName) terminal session: \(sessionTitle)"
        case .failed:
            return "Failed \(cliKind.displayName) terminal session: \(sessionTitle)"
        case .alert:
            return "Alert in \(cliKind.displayName) terminal session: \(sessionTitle)"
        case .waitingInput:
            return "Waiting for input in \(cliKind.displayName) terminal session: \(sessionTitle)"
        case .completed:
            return "Completed \(cliKind.displayName) terminal session: \(sessionTitle)"
        default:
            return "Running \(cliKind.displayName) terminal session: \(sessionTitle)"
        }
    }
}

private struct ObservationSnapshot {
    let events: [RawCLIEvent]
    let diagnostics: ObservationDiagnostics
}

private struct ObservationEventResult {
    let event: RawCLIEvent?
    let diagnostic: ObservationSessionDiagnostic
}

struct ObservedTerminalSession: Sendable {
    let snapshot: TerminalObservationSnapshot
    let transcript: String

    var transcriptPreview: String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "(空 transcript)"
        }

        if trimmed.count > 140 {
            return String(trimmed.prefix(140)) + "…"
        }
        return trimmed
    }

    var normalizedTranscript: String {
        ClaudeTranscriptNormalizer.normalize(transcript)
    }

    var normalizedTranscriptPreview: String {
        ClaudeTranscriptNormalizer.preview(for: transcript)
    }

    var normalizedTail: String {
        ClaudeTranscriptNormalizer.normalizedTail(from: transcript)
    }
}

struct TerminalReaderResult: Sendable {
    let readerID: String
    let readerName: String
    let terminalAppIdentifier: String
    let isAppRunning: Bool
    let fetchStatus: ObservationReaderFetchStatus
    let observations: [ObservedTerminalSession]
    let message: String
    let errorDescription: String?
}

protocol TerminalAppReading: Sendable {
    func fetchResult() -> TerminalReaderResult
}

struct AppleTerminalReader: TerminalAppReading {
    func fetchResult() -> TerminalReaderResult {
        let terminalAppIdentifier = "com.apple.Terminal"
        let outputResult = AppleScriptRunner.run(script: script)
        let observations = AppleScriptObservationParser.parse(
            output: outputResult.output,
            terminalAppIdentifier: terminalAppIdentifier
        )

        let isAppRunning = NSRunningApplication.runningApplications(withBundleIdentifier: terminalAppIdentifier).isEmpty == false
        let fetchStatus: ObservationReaderFetchStatus
        let message: String
        if !isAppRunning {
            fetchStatus = .notRunning
            message = "未检测到 Terminal 运行"
        } else if outputResult.output == nil {
            fetchStatus = .appleScriptError
            if let errorDescription = outputResult.errorDescription, !errorDescription.isEmpty {
                message = "AppleScript 执行失败：\(errorDescription)"
            } else {
                message = "AppleScript 执行失败或未获授权"
            }
        } else if observations.isEmpty {
            fetchStatus = .emptyResult
            message = "读取成功，但没有解析出可用 session"
        } else {
            fetchStatus = .success
            message = "已读取到 \(observations.count) 个 Terminal session"
        }

        return TerminalReaderResult(
            readerID: "terminal",
            readerName: "Terminal",
            terminalAppIdentifier: terminalAppIdentifier,
            isAppRunning: isAppRunning,
            fetchStatus: fetchStatus,
            observations: observations,
            message: message,
            errorDescription: outputResult.errorDescription
        )
    }

    private let script = #"""
        tell application "Terminal"
            set fieldDelimiter to "<<<MACIRLAND_FIELD>>>"
            set recordDelimiter to "<<<MACIRLAND_RECORD>>>"
            set output to ""
            repeat with eachWindow in windows
                set windowName to ""
                try
                    set windowName to name of eachWindow
                end try

                repeat with eachTab in tabs of eachWindow
                    set tabTitle to ""
                    set tabTTY to ""
                    set tabProcess to ""
                    set tabContents to ""

                    try
                        set tabTitle to custom title of eachTab
                    end try
                    if tabTitle is "" then
                        try
                            set tabTitle to name of eachTab
                        end try
                    end if
                    try
                        set tabTTY to tty of eachTab
                    end try
                    try
                        set tabProcess to processes of eachTab as text
                    on error
                        set tabProcess to ""
                    end try
                    try
                        set tabContents to history of eachTab
                    on error
                        set tabContents to ""
                    end try

                    set tabBusy to ""
                    try
                        set tabBusy to busy of eachTab as text
                    end try

                    set output to output & windowName & fieldDelimiter & tabTitle & fieldDelimiter & tabTTY & fieldDelimiter & tabProcess & fieldDelimiter & tabBusy & fieldDelimiter & tabContents & fieldDelimiter & windowName & recordDelimiter
                end repeat
            end repeat
            return output
        end tell
        """#
}

struct ITermReader: TerminalAppReading {
    func fetchResult() -> TerminalReaderResult {
        let terminalAppIdentifier = "com.googlecode.iterm2"
        let outputResult = AppleScriptRunner.run(script: script)
        let observations = AppleScriptObservationParser.parse(
            output: outputResult.output,
            terminalAppIdentifier: terminalAppIdentifier
        )

        let isAppRunning = NSRunningApplication.runningApplications(withBundleIdentifier: terminalAppIdentifier).isEmpty == false
        let fetchStatus: ObservationReaderFetchStatus
        let message: String
        if !isAppRunning {
            fetchStatus = .notRunning
            message = "未检测到 iTerm 运行"
        } else if outputResult.output == nil {
            fetchStatus = .appleScriptError
            if let errorDescription = outputResult.errorDescription, !errorDescription.isEmpty {
                message = "AppleScript 执行失败：\(errorDescription)"
            } else {
                message = "AppleScript 执行失败或未获授权"
            }
        } else if observations.isEmpty {
            fetchStatus = .emptyResult
            message = "读取成功，但没有解析出可用 session"
        } else {
            fetchStatus = .success
            message = "已读取到 \(observations.count) 个 iTerm session"
        }

        return TerminalReaderResult(
            readerID: "iterm",
            readerName: "iTerm",
            terminalAppIdentifier: terminalAppIdentifier,
            isAppRunning: isAppRunning,
            fetchStatus: fetchStatus,
            observations: observations,
            message: message,
            errorDescription: outputResult.errorDescription
        )
    }

    private let script = #"""
        tell application "iTerm"
            set fieldDelimiter to "<<<MACIRLAND_FIELD>>>"
            set recordDelimiter to "<<<MACIRLAND_RECORD>>>"
            set output to ""
            repeat with eachWindow in windows
                set windowName to ""
                try
                    set windowName to name of eachWindow
                end try

                repeat with eachTab in tabs of eachWindow
                    repeat with eachSession in sessions of eachTab
                        set sessionName to ""
                        set sessionTTY to ""
                        set sessionCommand to ""
                        set sessionContents to ""

                        try
                            set sessionName to name of eachSession
                        end try
                        try
                            set sessionTTY to tty of eachSession
                        end try
                        try
                            set sessionCommand to command of eachSession
                        end try
                        try
                            set sessionContents to contents of eachSession
                        end try

                        set output to output & windowName & fieldDelimiter & sessionName & fieldDelimiter & sessionTTY & fieldDelimiter & sessionCommand & fieldDelimiter & sessionContents & fieldDelimiter & windowName & recordDelimiter
                    end repeat
                end repeat
            end repeat
            return output
        end tell
        """#
}

struct AppleScriptExecutionResult: Sendable {
    let output: String?
    let errorDescription: String?
}

enum AppleScriptRunner {
    static func run(script: String) -> AppleScriptExecutionResult {
        guard let appleScript = NSAppleScript(source: script) else {
            return AppleScriptExecutionResult(output: nil, errorDescription: "无法创建 NSAppleScript 实例")
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard let error else {
            return AppleScriptExecutionResult(output: result.stringValue, errorDescription: nil)
        }

        let message = (error[NSAppleScript.errorMessage] as? String)
            ?? (error[NSAppleScript.errorBriefMessage] as? String)
            ?? error.description
        return AppleScriptExecutionResult(output: nil, errorDescription: message)
    }
}

enum AppleScriptObservationParser {
    private static let recordSeparator = "<<<MACIRLAND_RECORD>>>"
    private static let fieldSeparator = "<<<MACIRLAND_FIELD>>>"

    static func parse(output: String?, terminalAppIdentifier: String) -> [ObservedTerminalSession] {
        guard let output, !output.isEmpty else {
            return []
        }

        // Debug: log raw output to see observation format
        let debugLog = "OBS_PARSE_OUTPUT:\n\(output)\n---END---\n"
        try? debugLog.write(toFile: "/tmp/macirland-obs.log", atomically: true, encoding: .utf8)

        return output
            .components(separatedBy: recordSeparator)
            .compactMap { record in
                let trimmedRecord = record.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedRecord.isEmpty else {
                    return nil
                }

                let fields = trimmedRecord.components(separatedBy: fieldSeparator)
                guard fields.count >= 5 else {
                    return nil
                }

                let cleanedFields = fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let windowTitle = cleanedFields[0].isEmpty ? cleanedFields[1] : cleanedFields[0]
                let commandLine = cleanedFields[3]
                let hasBusyField = fields.count >= 6
                let busyField = hasBusyField ? cleanedFields[4] : ""
                // New 7-field format (added windowName at end): transcript excludes the trailing windowName field
                // Old 6-field format: transcript includes everything from field 5 onwards
                let transcript: String
                let fullWindowName: String
                if fields.count >= 7 {
                    // New format: last field is windowName, transcript is fields 5 onwards excluding last
                    transcript = fields.dropFirst(5).dropLast().joined(separator: fieldSeparator)
                    fullWindowName = cleanedFields[cleanedFields.count - 1]
                } else {
                    transcript = hasBusyField
                        ? fields.dropFirst(5).joined(separator: fieldSeparator)
                        : fields.dropFirst(4).joined(separator: fieldSeparator)
                    fullWindowName = ""
                }

                guard !windowTitle.isEmpty || !commandLine.isEmpty else {
                    return nil
                }

                return ObservedTerminalSession(
                    snapshot: TerminalObservationSnapshot(
                        terminalAppIdentifier: terminalAppIdentifier,
                        windowTitle: windowTitle,
                        fullWindowName: fullWindowName,
                        commandLine: commandLine,
                        ttyIdentifier: cleanedFields[2].nilIfEmpty,
                        isBusy: parseBusyFlag(busyField)
                    ),
                    transcript: transcript
                )
            }
    }

    private static func parseBusyFlag(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
}

enum ClaudeSnapshotMatcher {
    static func recognizes(snapshot: TerminalObservationSnapshot) -> Bool {
        recognizes(snapshot: snapshot, transcript: "")
    }

    static func recognizes(snapshot: TerminalObservationSnapshot, transcript: String) -> Bool {
        let windowTitle = snapshot.windowTitle.lowercased()
        if windowTitle.contains("claude code") {
            return true
        }

        let commandLine = normalizedCommandLine(snapshot.commandLine)
        if !commandLine.isEmpty {
            let tokens = commandTokens(in: commandLine)
            if let claudeIndex = tokens.firstIndex(of: "claude") {
                let disallowedPreviousTokens: Set<String> = [
                    "about",
                    "docs",
                    "documenting",
                    "echo",
                    "grep",
                    "notes",
                    "readme",
                    "rg",
                    "vim"
                ]

                if claudeIndex > 0 {
                    let previous = tokens[claudeIndex - 1]
                    if disallowedPreviousTokens.contains(previous) {
                        return false
                    }
                }

                return true
            }
        }

        return recognizesTranscriptHeader(transcript)
    }

    private static func recognizesTranscriptHeader(_ transcript: String) -> Bool {
        let lowered = ClaudeTranscriptNormalizer
            .normalizedHead(from: transcript, maxLength: 2000)
            .lowercased()
        guard lowered.isEmpty == false else {
            return false
        }

        let strongSignals = [
            "claude code v",
            "api usage billing"
        ]
        let mediumSignals = [
            "sonnet ",
            "opus ",
            "haiku ",
            "1m context",
            "~/documents/",
            "read …",
            "read ..."
        ]

        let strongCount = strongSignals.filter { lowered.contains($0) }.count
        let mediumCount = mediumSignals.filter { lowered.contains($0) }.count

        return strongCount >= 2 || (strongCount >= 1 && mediumCount >= 1)
    }
    private static func normalizedCommandLine(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func commandTokens(in commandLine: String) -> [String] {
        commandLine
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                token
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'()[]{}<>"))
                    .split(separator: "/")
                    .last
                    .map(String.init) ?? String(token)
            }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func containsAny(of fragments: [String]) -> Bool {
        fragments.contains(where: contains)
    }
}
