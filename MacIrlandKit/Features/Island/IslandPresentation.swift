import SwiftUI

public struct CompactIslandPresentation: Equatable {
    public let statusText: String
    public let countText: String
    public let secondaryText: String?
    public let accessibilityLabel: String
    public let accentColor: Color

    public init(summary: AppTaskSummary, preferredSession: TaskSession?, secondaryCount: Int) {
        if let session = preferredSession {
            switch session.status {
            case .waitingInput:
                statusText = "等待回复"
            case .failed, .contextLost:
                statusText = "需要处理"
            case .alert:
                statusText = "发现异常"
            case .replyAvailable:
                statusText = "可直接回复"
            case .running:
                statusText = "运行中"
            case .completed:
                statusText = "已完成"
            case .discovered, .recognizing:
                statusText = "识别中"
            }
            accentColor = IslandAccent.color(for: session.status)
        } else {
            statusText = "空闲"
            accentColor = .green
        }

        let totalCount = summary.attentionCount + summary.runningCount + summary.completedCount
        countText = "\(totalCount) 个会话"

        if secondaryCount > 0 {
            secondaryText = "另 \(secondaryCount) 个待处理"
        } else {
            secondaryText = nil
        }

        accessibilityLabel = "MacIrland，\(statusText)，\(countText)"
    }
}

public struct HighlightedIslandPresentation: Equatable {
    public let sessionID: TaskSession.ID
    public let status: TaskStatus
    public let titleText: String
    public let summaryText: String
    public let sourceText: String
    public let timeText: String
    public let queueHintText: String?
    public let accessibilityLabel: String
    public let accentColor: Color
    public let primaryAction: ReplyActionType?
    public let primaryActionTitle: String?
    public let primaryActionAvailable: Bool
    public let primaryActionUnavailableReason: String?
    public let autoCollapseDelay: TimeInterval?

    public init?(topSession: TaskSession?, queueCount: Int = 0) {
        guard let topSession, topSession.status.needsAttention else {
            return nil
        }

        let visibleQuickActions = topSession.quickActions.filter { $0 != .customText }

        sessionID = topSession.id
        status = topSession.status
        titleText = topSession.title
        summaryText = topSession.compactSessionSubtitle
        sourceText = topSession.sourceCLI.displayName
        timeText = topSession.relativeLastActiveText
        queueHintText = queueCount > 0 ? "后面还有 \(queueCount) 个会话待处理" : nil
        accessibilityLabel = "MacIrland，\(titleText)，\(summaryText)，来自 \(sourceText)"
        accentColor = IslandAccent.color(for: topSession.status)
        primaryAction = visibleQuickActions.first
        primaryActionTitle = visibleQuickActions.first?.title

        let canSend = topSession.replyCapability.canSendSafely
        primaryActionAvailable = canSend && visibleQuickActions.first != nil
        primaryActionUnavailableReason = primaryActionAvailable ? nil : topSession.replyCapability.reason

        switch topSession.status {
        case .alert:
            autoCollapseDelay = 8
        case .replyAvailable:
            autoCollapseDelay = 12
        case .waitingInput, .failed, .contextLost:
            autoCollapseDelay = nil
        default:
            autoCollapseDelay = nil
        }
    }
}
