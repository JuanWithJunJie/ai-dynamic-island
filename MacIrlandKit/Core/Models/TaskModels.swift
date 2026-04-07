import Foundation

public enum CLIKind: String, CaseIterable, Codable, Sendable {
    case codex
    case claudeCode
    case gemini
    case unknown

    public var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claudeCode:
            return "Claude Code"
        case .gemini:
            return "Gemini CLI"
        case .unknown:
            return "Unknown CLI"
        }
    }
}

public enum TaskStatus: String, CaseIterable, Codable, Sendable {
    case discovered
    case recognizing
    case running
    case waitingInput
    case replyAvailable
    case alert
    case completed
    case failed
    case contextLost

    public var label: String {
        switch self {
        case .discovered:
            return "已发现"
        case .recognizing:
            return "识别中"
        case .running:
            return "运行中"
        case .waitingInput:
            return "等待输入"
        case .replyAvailable:
            return "可回复"
        case .alert:
            return "异常告警"
        case .completed:
            return "已完成"
        case .failed:
            return "已失败"
        case .contextLost:
            return "上下文丢失"
        }
    }

    public var needsAttention: Bool {
        switch self {
        case .waitingInput, .replyAvailable, .alert, .failed, .contextLost:
            return true
        case .discovered, .recognizing, .running, .completed:
            return false
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .contextLost:
            return true
        case .discovered, .recognizing, .running, .waitingInput, .replyAvailable, .alert:
            return false
        }
    }
}

public enum ConfidenceLevel: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum EvidenceSourceType: String, Codable, Sendable {
    case window
    case tty
    case log
    case adapter
    case bridge
    case manual
}

public enum MessageSnippetKind: String, Codable, Sendable {
    case assistant
    case user
    case system
    case log
    case error
}

public enum SessionEventKind: String, Codable, Sendable {
    case started
    case resumed
    case waitingForInput
    case replyCapabilityChanged
    case warning
    case error
    case completed
    case failed
    case contextLost
}

public enum ReplyCapabilityStatus: String, Codable, Sendable {
    case unavailable
    case manualConfirmationRequired
    case available
}

public enum ReplyActionType: String, CaseIterable, Codable, Sendable {
    case continueExecution
    case retry
    case explainReason
    case stop
    case supplementInfo
    case customText

    public var title: String {
        switch self {
        case .continueExecution:
            return "继续执行"
        case .retry:
            return "重试"
        case .explainReason:
            return "解释原因"
        case .stop:
            return "停止"
        case .supplementInfo:
            return "补充信息"
        case .customText:
            return "发送文本"
        }
    }

    public var defaultMessage: String {
        switch self {
        case .continueExecution:
            return "请继续执行。"
        case .retry:
            return "请重试上一步，并说明变化。"
        case .explainReason:
            return "请解释一下为什么会出现当前结果。"
        case .stop:
            return "先停止当前操作。"
        case .supplementInfo:
            return "我补充一点信息："
        case .customText:
            return ""
        }
    }
}

public enum SoundMode: String, CaseIterable, Codable, Sendable {
    case all
    case criticalOnly
    case mute
}

public enum SoundCue: String, Codable, Sendable {
    case taskStarted
    case waitingForReply
    case completed
    case failed
}

public struct EvidenceItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sourceType: EvidenceSourceType
    public let summary: String
    public let rawSnippet: String
    public let weight: Double

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        sourceType: EvidenceSourceType,
        summary: String,
        rawSnippet: String,
        weight: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceType = sourceType
        self.summary = summary
        self.rawSnippet = rawSnippet
        self.weight = weight
    }
}

public struct MessageSnippet: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: MessageSnippetKind
    public let text: String
    public let isHighlighted: Bool
    public let isError: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: MessageSnippetKind,
        text: String,
        isHighlighted: Bool = false,
        isError: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.text = text
        self.isHighlighted = isHighlighted
        self.isError = isError
    }
}

public struct BridgeTarget: Hashable, Codable, Sendable {
    public let cliKind: CLIKind
    public let sessionID: UUID
    public let terminalContext: String
    public let channelType: String
    public let displayName: String

    public init(
        cliKind: CLIKind,
        sessionID: UUID,
        terminalContext: String,
        channelType: String,
        displayName: String
    ) {
        self.cliKind = cliKind
        self.sessionID = sessionID
        self.terminalContext = terminalContext
        self.channelType = channelType
        self.displayName = displayName
    }
}

public struct ReplyCapability: Hashable, Codable, Sendable {
    public let status: ReplyCapabilityStatus
    public let reason: String
    public let targetDescription: String
    public let channelStatus: String

    public init(
        status: ReplyCapabilityStatus,
        reason: String,
        targetDescription: String,
        channelStatus: String
    ) {
        self.status = status
        self.reason = reason
        self.targetDescription = targetDescription
        self.channelStatus = channelStatus
    }

    public var canSendSafely: Bool {
        status == .available
    }
}

public struct SessionIdentity: Hashable, Codable, Sendable {
    public let id: UUID
    public let cliKind: CLIKind
    public let terminalAppIdentifier: String
    public let windowIdentifier: String
    public let ttyIdentifier: String?
    public let startedAt: Date
    public let lastSeenAt: Date

    public init(
        id: UUID = UUID(),
        cliKind: CLIKind,
        terminalAppIdentifier: String,
        windowIdentifier: String,
        ttyIdentifier: String?,
        startedAt: Date,
        lastSeenAt: Date
    ) {
        self.id = id
        self.cliKind = cliKind
        self.terminalAppIdentifier = terminalAppIdentifier
        self.windowIdentifier = windowIdentifier
        self.ttyIdentifier = ttyIdentifier
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
    }
}

public struct SessionEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: SessionEventKind
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: SessionEventKind,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
    }
}

public enum SessionHistoryKind: String, Codable, Sendable {
    case phaseDiscovered
    case phaseRunning
    case phaseWaitingInput
    case phaseReplyAvailable
    case phaseAlert
    case phaseCompleted
    case phaseFailed
    case phaseContextLost
    case userQuickAction
    case userCustomReply
    case userReplyRejected
}

public struct SessionHistoryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: SessionHistoryKind
    public let title: String
    public let detail: String
    public let relatedStatus: TaskStatus?

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: SessionHistoryKind,
        title: String,
        detail: String,
        relatedStatus: TaskStatus? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.detail = detail
        self.relatedStatus = relatedStatus
    }
}

public struct TaskSession: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let identity: SessionIdentity
    public let title: String
    public let status: TaskStatus
    public let priority: Int
    public let confidence: Double
    public let summary: String
    public let bridgeTarget: BridgeTarget?
    public let replyCapability: ReplyCapability
    public let lastActiveAt: Date
    public let evidence: [EvidenceItem]
    public let recentEvents: [SessionEvent]
    public let recentMessages: [MessageSnippet]
    public let historyEntries: [SessionHistoryEntry]
    public let quickActions: [ReplyActionType]

    public init(
        id: UUID = UUID(),
        identity: SessionIdentity,
        title: String,
        status: TaskStatus,
        priority: Int,
        confidence: Double,
        summary: String,
        bridgeTarget: BridgeTarget?,
        replyCapability: ReplyCapability,
        lastActiveAt: Date,
        evidence: [EvidenceItem],
        recentEvents: [SessionEvent],
        recentMessages: [MessageSnippet],
        historyEntries: [SessionHistoryEntry] = [],
        quickActions: [ReplyActionType]
    ) {
        self.id = id
        self.identity = identity
        self.title = title
        self.status = status
        self.priority = priority
        self.confidence = confidence
        self.summary = summary
        self.bridgeTarget = bridgeTarget
        self.replyCapability = replyCapability
        self.lastActiveAt = lastActiveAt
        self.evidence = evidence
        self.recentEvents = recentEvents
        self.recentMessages = recentMessages
        self.historyEntries = historyEntries
        self.quickActions = quickActions
    }

    public var sourceCLI: CLIKind {
        identity.cliKind
    }

    public var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case ..<0.45:
            return .low
        case 0.45..<0.8:
            return .medium
        default:
            return .high
        }
    }

    public var canReplySafely: Bool {
        status == .replyAvailable && replyCapability.canSendSafely && bridgeTarget != nil
    }

    public var isAwaitingUser: Bool {
        status == .waitingInput || status == .replyAvailable
    }

    public func withHistoryEntries(_ historyEntries: [SessionHistoryEntry]) -> TaskSession {
        TaskSession(
            id: id,
            identity: identity,
            title: title,
            status: status,
            priority: priority,
            confidence: confidence,
            summary: summary,
            bridgeTarget: bridgeTarget,
            replyCapability: replyCapability,
            lastActiveAt: lastActiveAt,
            evidence: evidence,
            recentEvents: recentEvents,
            recentMessages: recentMessages,
            historyEntries: historyEntries,
            quickActions: quickActions
        )
    }
}

public struct AppTaskSummary: Hashable, Codable, Sendable {
    public let runningCount: Int
    public let waitingCount: Int
    public let completedCount: Int
    public let alertCount: Int
    public let topPrioritySessionID: UUID?

    public init(
        runningCount: Int,
        waitingCount: Int,
        completedCount: Int,
        alertCount: Int,
        topPrioritySessionID: UUID?
    ) {
        self.runningCount = runningCount
        self.waitingCount = waitingCount
        self.completedCount = completedCount
        self.alertCount = alertCount
        self.topPrioritySessionID = topPrioritySessionID
    }
}

public struct CapabilityStatus: Hashable, Codable, Sendable {
    public let accessibilityGranted: Bool
    public let localOnlyProcessing: Bool
    public let explanation: String
    public let observationBlocked: Bool

    public init(
        accessibilityGranted: Bool,
        localOnlyProcessing: Bool,
        explanation: String,
        observationBlocked: Bool = false
    ) {
        self.accessibilityGranted = accessibilityGranted
        self.localOnlyProcessing = localOnlyProcessing
        self.explanation = explanation
        self.observationBlocked = observationBlocked
    }
}

public enum ObservationReaderFetchStatus: String, Codable, Sendable {
    case notRunning
    case success
    case emptyResult
    case appleScriptError

    public var label: String {
        switch self {
        case .notRunning:
            return "未运行"
        case .success:
            return "读取成功"
        case .emptyResult:
            return "无可读结果"
        case .appleScriptError:
            return "脚本失败"
        }
    }
}

public struct ObservationReaderDiagnostic: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let readerName: String
    public let terminalAppIdentifier: String
    public let isAppRunning: Bool
    public let fetchStatus: ObservationReaderFetchStatus
    public let observationCount: Int
    public let recognizedEventCount: Int
    public let message: String
    public let errorDescription: String?

    public init(
        id: String,
        readerName: String,
        terminalAppIdentifier: String,
        isAppRunning: Bool,
        fetchStatus: ObservationReaderFetchStatus,
        observationCount: Int,
        recognizedEventCount: Int,
        message: String,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.readerName = readerName
        self.terminalAppIdentifier = terminalAppIdentifier
        self.isAppRunning = isAppRunning
        self.fetchStatus = fetchStatus
        self.observationCount = observationCount
        self.recognizedEventCount = recognizedEventCount
        self.message = message
        self.errorDescription = errorDescription
    }
}

public struct ObservationSessionDiagnostic: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let terminalAppIdentifier: String
    public let windowTitle: String
    public let commandLine: String
    public let ttyIdentifier: String?
    public let transcriptPreview: String
    public let recognizedCLIKind: CLIKind?
    public let inferredStatus: TaskStatus?
    public let decisionReason: String

    public init(
        id: UUID = UUID(),
        terminalAppIdentifier: String,
        windowTitle: String,
        commandLine: String,
        ttyIdentifier: String?,
        transcriptPreview: String,
        recognizedCLIKind: CLIKind?,
        inferredStatus: TaskStatus?,
        decisionReason: String
    ) {
        self.id = id
        self.terminalAppIdentifier = terminalAppIdentifier
        self.windowTitle = windowTitle
        self.commandLine = commandLine
        self.ttyIdentifier = ttyIdentifier
        self.transcriptPreview = transcriptPreview
        self.recognizedCLIKind = recognizedCLIKind
        self.inferredStatus = inferredStatus
        self.decisionReason = decisionReason
    }
}

public struct ObservationDiagnostics: Hashable, Codable, Sendable {
    public let timestamp: Date
    public let readers: [ObservationReaderDiagnostic]
    public let sessions: [ObservationSessionDiagnostic]

    public init(
        timestamp: Date = .now,
        readers: [ObservationReaderDiagnostic],
        sessions: [ObservationSessionDiagnostic]
    ) {
        self.timestamp = timestamp
        self.readers = readers
        self.sessions = sessions
    }
}

public struct TerminalObservationSnapshot: Hashable, Codable, Sendable {
    public let terminalAppIdentifier: String
    public let windowTitle: String
    public let commandLine: String
    public let ttyIdentifier: String?

    public init(
        terminalAppIdentifier: String,
        windowTitle: String,
        commandLine: String,
        ttyIdentifier: String?
    ) {
        self.terminalAppIdentifier = terminalAppIdentifier
        self.windowTitle = windowTitle
        self.commandLine = commandLine
        self.ttyIdentifier = ttyIdentifier
    }
}

public struct RawCLIEvent: Hashable, Codable, Sendable {
    public let cliKind: CLIKind
    public let timestamp: Date
    public let snippet: String
    public let snapshot: TerminalObservationSnapshot

    public init(
        cliKind: CLIKind,
        timestamp: Date = .now,
        snippet: String,
        snapshot: TerminalObservationSnapshot
    ) {
        self.cliKind = cliKind
        self.timestamp = timestamp
        self.snippet = snippet
        self.snapshot = snapshot
    }
}
