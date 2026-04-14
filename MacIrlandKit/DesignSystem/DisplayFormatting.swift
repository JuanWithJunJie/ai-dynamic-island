import Foundation

public typealias SessionTimelineEntry = SessionHistoryEntry

public extension SessionHistoryEntry {
    var systemImage: String {
        switch kind {
        case .phaseDiscovered, .phaseRunning:
            return "bolt.fill"
        case .phaseWaitingInput:
            return "hand.raised.fill"
        case .phaseReplyAvailable:
            return "paperplane.fill"
        case .phaseAlert:
            return "exclamationmark.triangle.fill"
        case .phaseCompleted:
            return "checkmark.circle.fill"
        case .phaseFailed, .userReplyRejected:
            return "xmark.octagon.fill"
        case .phaseContextLost:
            return "questionmark.circle.fill"
        case .userQuickAction, .userCustomReply:
            return "person.fill.badge.plus"
        }
    }

    var tint: TaskStatus {
        if let relatedStatus {
            return relatedStatus
        }

        switch kind {
        case .phaseDiscovered:
            return .discovered
        case .phaseRunning:
            return .running
        case .phaseWaitingInput:
            return .waitingInput
        case .phaseReplyAvailable:
            return .replyAvailable
        case .phaseAlert:
            return .alert
        case .phaseCompleted:
            return .completed
        case .phaseFailed, .userReplyRejected:
            return .failed
        case .phaseContextLost:
            return .contextLost
        case .userQuickAction, .userCustomReply:
            return .waitingInput
        }
    }

    var timeText: String {
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

    var projectDisplayName: String {
        if let extracted = normalizedProjectNameCandidate(title) {
            return extracted
        }

        let sessionName = identity.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let extractedSessionName = normalizedProjectNameCandidate(sessionName),
           extractedSessionName.count > 1 {
            return extractedSessionName
        }

        let windowIdentifier = identity.windowIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if let extractedWindowName = normalizedProjectNameCandidate(windowIdentifier) {
            return extractedWindowName
        }

        let commandLine = identity.commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !commandLine.isEmpty {
            let components = commandLine.split(separator: "/")
            if let last = components.last {
                let fallback = String(last).trimmingCharacters(in: .whitespacesAndNewlines)
                if !fallback.isEmpty {
                    return fallback
                }
            }
            return commandLine
        }

        return title
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

    var timelineEntries: [SessionHistoryEntry] {
        historyEntries.sorted { $0.timestamp > $1.timestamp }
    }
}


private func normalizedProjectNameCandidate(_ rawValue: String) -> String? {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
        return nil
    }

    if let range = value.range(of: ": ") {
        let suffix = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedSuffix = normalizedProjectNameCandidate(suffix) {
            return normalizedSuffix
        }
    }

    let separators = [" — ", " – ", " · "]
    for separator in separators {
        let parts = value.components(separatedBy: separator).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if parts.count >= 2 {
            let first = parts.first ?? ""
            let last = parts.last ?? ""
            let trailing = parts.dropFirst().joined(separator: separator)

            if trailing.localizedCaseInsensitiveContains("claude"),
               let normalizedFirst = normalizedProjectNameCandidate(first) {
                return normalizedFirst
            }

            if first.localizedCaseInsensitiveContains("claude"),
               let normalizedLast = normalizedProjectNameCandidate(last) {
                return normalizedLast
            }

            if let normalizedFirst = normalizedProjectNameCandidate(first), first != value {
                return normalizedFirst
            }
        }
    }

    let trimmed = value
        .trimmingCharacters(in: CharacterSet(charactersIn: "·•✳⠂◦●"))
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
        return nil
    }

    let lowercased = trimmed.lowercased()
    let genericNames = [
        "claude",
        "claude code",
        "running claude code terminal session",
        "completed claude code terminal session"
    ]
    if genericNames.contains(lowercased) || lowercased.contains("claude code (") {
        return nil
    }

    return trimmed
}

public extension AppTaskSummary {
    var attentionCount: Int {
        waitingCount + alertCount
    }

    var totalCount: Int {
        runningCount + waitingCount + completedCount + alertCount
    }
}
