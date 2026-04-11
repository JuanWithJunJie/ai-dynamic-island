import Foundation

/// Hook event types registered in the minimal viable version.
public enum HookEventType: String, Codable, Sendable {
    case userPromptSubmit = "UserPromptSubmit"
    case postToolUse = "PostToolUse"
    case permissionRequest = "PermissionRequest"
    case stop = "Stop"
    case sessionEnd = "SessionEnd"
    case notification = "Notification"
    case preCompact = "PreCompact"

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = HookEventType(rawValue: rawValue) ?? .notification
    }
}

/// Hook-driven session status, derived from hook events.
public enum HookSessionStatus: String, Codable, Sendable {
    case idle
    case running
    case waitingForReply
    case completed
}

/// A single event emitted by the Python hook via Unix socket.
public struct HookEvent: Codable, Sendable {
    public enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cwd
        case event
        case status
        case pid
        case tty
        case tool
        case toolInput = "tool_input"
        case toolUseID = "tool_use_id"
        case notificationType = "notification_type"
    }

    /// Unique Claude Code session identifier.
    public let sessionID: String

    /// Current working directory at time of event.
    public let cwd: String

    /// Event type (e.g. "PostToolUse", "Stop").
    public let event: HookEventType

    /// Human-readable status derived from the event.
    public let status: String

    /// Process ID of the Claude Code instance that emitted this event.
    public let pid: Int

    /// Terminal device path (e.g. "/dev/ttys007").
    public let tty: String

    /// Tool that was used (if applicable).
    public let tool: String?

    /// Input to the tool call (JSON string representation).
    /// Note: currently not decoded to avoid AnyCodable complexity
    public let toolInput: String?

    /// Unique identifier for this tool use.
    public let toolUseID: String?

    /// Only present when event is "Notification".
    public let notificationType: String?

    public init(
        sessionID: String,
        cwd: String,
        event: HookEventType,
        status: String,
        pid: Int,
        tty: String,
        tool: String? = nil,
        toolInput: String? = nil,
        toolUseID: String? = nil,
        notificationType: String? = nil
    ) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.event = event
        self.status = status
        self.pid = pid
        self.tty = tty
        self.tool = tool
        self.toolInput = toolInput
        self.toolUseID = toolUseID
        self.notificationType = notificationType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionID = try container.decode(String.self, forKey: .sessionID)
        self.cwd = try container.decode(String.self, forKey: .cwd)
        self.event = try container.decode(HookEventType.self, forKey: .event)
        self.status = try container.decode(String.self, forKey: .status)
        self.pid = try container.decode(Int.self, forKey: .pid)
        self.tty = try container.decode(String.self, forKey: .tty)
        self.tool = try container.decodeIfPresent(String.self, forKey: .tool)
        self.toolInput = try container.decodeIfPresent(String.self, forKey: .toolInput)
        self.toolUseID = try container.decodeIfPresent(String.self, forKey: .toolUseID)
        self.notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType)
    }

    /// Converts this hook event to a hook-driven session status.
    public var hookStatus: HookSessionStatus {
        switch event {
        case .userPromptSubmit, .postToolUse:
            return .running
        case .permissionRequest:
            return .waitingForReply
        case .stop, .sessionEnd:
            return .completed
        case .notification, .preCompact:
            return .idle
        }
    }
}

/// Response sent back to the Python hook for permission requests.
public struct HookResponse: Codable, Sendable {
    public enum Decision: String, Codable, Sendable {
        case allow
        case deny
    }

    public let decision: Decision
    public let reason: String?

    public init(decision: Decision, reason: String? = nil) {
        self.decision = decision
        self.reason = reason
    }
}

/// A type-erased Codable value for tool inputs that may be any JSON type.
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encodeNil()
        }
    }
}
