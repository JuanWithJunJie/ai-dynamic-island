import Foundation

public struct SessionTimelineEntry: Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let title: String
    public let detail: String
    public let systemImage: String
    public let tint: TaskStatus

    public var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

public extension TaskSession {
    var terminalDisplayName: String {
        switch identity.terminalAppIdentifier {
        case "com.apple.Terminal":
            return "Terminal"
        case "com.googlecode.iterm2":
            return "iTerm2"
        default:
            return "Shell"
        }
    }

    var relativeLastActiveText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastActiveAt, relativeTo: .now)
    }

    var primaryGuidanceText: String {
        switch status {
        case .waitingInput, .replyAvailable:
            return "等待你确认、补充信息或继续执行。"
        case .alert, .failed:
            return "当前会话出现异常，优先查看错误并决定是否重试。"
        case .completed:
            return "这条会话已经完成，可以复核结果或切换到其他任务。"
        case .contextLost:
            return "当前上下文已丢失，建议重新建立会话或补充背景。"
        case .running:
            return "当前正在持续执行，适合继续观察进展和最近输出。"
        case .discovered, .recognizing:
            return "正在识别会话状态，稍后这里会出现更完整的任务信息。"
        }
    }

    var timelineEntries: [SessionTimelineEntry] {
        let eventEntries = recentEvents.map { event in
            SessionTimelineEntry(
                id: event.id,
                timestamp: event.timestamp,
                title: event.kind.displayTitle,
                detail: event.message,
                systemImage: event.kind.systemImage,
                tint: event.kind.accentStatus
            )
        }

        let messageEntries = recentMessages.map { message in
            SessionTimelineEntry(
                id: message.id,
                timestamp: message.timestamp,
                title: message.kind.displayTitle,
                detail: message.text,
                systemImage: message.kind.systemImage,
                tint: message.isError ? .failed : (message.isHighlighted ? .waitingInput : status)
            )
        }

        return (messageEntries + eventEntries).sorted { $0.timestamp > $1.timestamp }
    }
}

public extension AppTaskSummary {
    var attentionCount: Int {
        waitingCount + alertCount
    }

    var totalCount: Int {
        runningCount + waitingCount + completedCount + alertCount
    }
}

private extension SessionEventKind {
    var displayTitle: String {
        switch self {
        case .started:
            return "Started"
        case .resumed:
            return "Resumed"
        case .waitingForInput:
            return "Waiting"
        case .replyCapabilityChanged:
            return "Reply Ready"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .contextLost:
            return "Context Lost"
        }
    }

    var systemImage: String {
        switch self {
        case .started, .resumed:
            return "bolt.fill"
        case .waitingForInput:
            return "hand.raised.fill"
        case .replyCapabilityChanged:
            return "paperplane.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error, .failed:
            return "xmark.octagon.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .contextLost:
            return "questionmark.circle.fill"
        }
    }

    var accentStatus: TaskStatus {
        switch self {
        case .waitingForInput:
            return .waitingInput
        case .replyCapabilityChanged:
            return .replyAvailable
        case .warning:
            return .alert
        case .error, .failed:
            return .failed
        case .completed:
            return .completed
        case .contextLost:
            return .contextLost
        case .started, .resumed:
            return .running
        }
    }
}

private extension MessageSnippetKind {
    var displayTitle: String {
        switch self {
        case .assistant:
            return "最新消息"
        case .user:
            return "你的输入"
        case .system:
            return "系统提示"
        case .log:
            return "日志"
        case .error:
            return "错误输出"
        }
    }

    var systemImage: String {
        switch self {
        case .assistant:
            return "sparkles"
        case .user:
            return "person.fill"
        case .system:
            return "gearshape.fill"
        case .log:
            return "text.alignleft"
        case .error:
            return "exclamationmark.octagon.fill"
        }
    }
}
