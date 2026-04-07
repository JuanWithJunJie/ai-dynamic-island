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

enum ClaudeStatusJudge {
    static func judge(transcript: String) -> ClaudeStatusJudgement {
        let lowercased = transcript.lowercasedTail(maxLength: 2400)
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
                "awaiting your confirmation"
            ],
            mediumSignals: [
                "please confirm",
                "press enter",
                "press return",
                "approve?",
                "confirm to continue"
            ],
            weakSignals: [
                "y/n",
                "yes/no",
                "press any key",
                "enter to continue"
            ],
            antiSignals: [
                "i can confirm",
                "can confirm",
                "confirmed that",
                "confirmation message"
            ]
        )

        let replyAvailableScore = score(
            in: lowercased,
            strongSignals: [
                "draft reply",
                "reply available"
            ],
            mediumSignals: [
                "respond to continue",
                "reply to continue",
                "waiting for reply"
            ],
            weakSignals: [
                "reply",
                "respond"
            ],
            antiSignals: [
                "reply capability",
                "response time"
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
                "finished generating"
            ],
            mediumSignals: [
                "task complete",
                "all set",
                "done successfully"
            ],
            weakSignals: [
                "completed",
                "finished"
            ],
            antiSignals: [
                "not done",
                "not completed",
                "not finished",
                "unfinished",
                "we are not done"
            ]
        )

        let candidates: [(TaskStatus, SignalScore)] = [
            (.contextLost, contextLostScore),
            (.failed, failedScore),
            (.waitingInput, waitingInputScore),
            (.replyAvailable, replyAvailableScore),
            (.alert, alertScore),
            (.completed, completedScore)
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
            return signal.hasStrongSignal || signal.total >= 4 || (signal.hasMediumSignal && signal.matchedSignals >= 2)
        default:
            return false
        }
    }

    private static func normalizedSessionSnippetJudgement(for text: String) -> ClaudeStatusJudgement? {
        if text.hasPrefix("context lost in claude code terminal session:") {
            return ClaudeStatusJudgement(status: .contextLost, confidence: 0.9, matchedSignals: 1, dominantReason: "normalized context-lost snippet")
        }
        if text.hasPrefix("failed claude code terminal session:") {
            return ClaudeStatusJudgement(status: .failed, confidence: 0.9, matchedSignals: 1, dominantReason: "normalized failed snippet")
        }
        if text.hasPrefix("alert in claude code terminal session:") {
            return ClaudeStatusJudgement(status: .alert, confidence: 0.88, matchedSignals: 1, dominantReason: "normalized alert snippet")
        }
        if text.hasPrefix("waiting for input in claude code terminal session:") {
            return ClaudeStatusJudgement(status: .waitingInput, confidence: 0.88, matchedSignals: 1, dominantReason: "normalized waiting snippet")
        }
        if text.hasPrefix("completed claude code terminal session:") {
            return ClaudeStatusJudgement(status: .completed, confidence: 0.88, matchedSignals: 1, dominantReason: "normalized completed snippet")
        }
        if text.hasPrefix("running claude code terminal session:") {
            return ClaudeStatusJudgement(status: .running, confidence: 0.72, matchedSignals: 1, dominantReason: "normalized running snippet")
        }
        return nil
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
                    recognizedCLIKind: nil,
                    inferredStatus: nil,
                    decisionReason: "未命中 Claude Code 识别规则"
                )
            )
        }

        let status = inferredStatus(for: observation)
        let event = RawCLIEvent(
            cliKind: cliKind,
            snippet: snippet(for: observation.snapshot, cliKind: cliKind, status: status),
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
                recognizedCLIKind: cliKind,
                inferredStatus: status,
                decisionReason: "已识别并转成 \(cliKind.displayName) 事件"
            )
        )
    }

    private static func recognizedCLIKind(for observation: ObservedTerminalSession) -> CLIKind? {
        if ClaudeSnapshotMatcher.recognizes(snapshot: observation.snapshot, transcript: observation.transcript) {
            return .claudeCode
        }

        return nil
    }

    private static func inferredStatus(for observation: ObservedTerminalSession) -> TaskStatus {
        ClaudeStatusJudge.judge(transcript: observation.transcript).status
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
                    end try
                    try
                        set tabContents to contents of eachTab
                    end try

                    set output to output & windowName & fieldDelimiter & tabTitle & fieldDelimiter & tabTTY & fieldDelimiter & tabProcess & fieldDelimiter & tabContents & recordDelimiter
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

                        set output to output & windowName & fieldDelimiter & sessionName & fieldDelimiter & sessionTTY & fieldDelimiter & sessionCommand & fieldDelimiter & sessionContents & recordDelimiter
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

                guard !windowTitle.isEmpty || !commandLine.isEmpty else {
                    return nil
                }

                return ObservedTerminalSession(
                    snapshot: TerminalObservationSnapshot(
                        terminalAppIdentifier: terminalAppIdentifier,
                        windowTitle: windowTitle,
                        commandLine: commandLine,
                        ttyIdentifier: cleanedFields[2].nilIfEmpty
                    ),
                    transcript: fields.dropFirst(4).joined(separator: fieldSeparator)
                )
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
        let lowered = transcript.lowercasedHead(maxLength: 2000)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func containsAny(of fragments: [String]) -> Bool {
        fragments.contains(where: contains)
    }

    func lowercasedTail(maxLength: Int) -> String {
        let lowered = lowercased()
        guard lowered.count > maxLength else {
            return lowered
        }
        return String(lowered.suffix(maxLength))
    }

    func lowercasedHead(maxLength: Int) -> String {
        let lowered = lowercased()
        guard lowered.count > maxLength else {
            return lowered
        }
        return String(lowered.prefix(maxLength))
    }
}
