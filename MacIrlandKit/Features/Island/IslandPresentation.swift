import SwiftUI

public struct CompactIslandPresentation: Equatable {
    public let statusText: String
    public let countText: String
    public let accessibilityLabel: String
    public let accentColor: Color

    public init(summary: AppTaskSummary, topSession: TaskSession?) {
        if summary.attentionCount > 0 {
            statusText = "等待处理"
            countText = "\(summary.attentionCount) 个会话"
        } else if summary.runningCount > 0 {
            statusText = "运行中"
            countText = "\(summary.runningCount) 个会话"
        } else if summary.completedCount > 0 {
            statusText = "已完成"
            countText = "\(summary.completedCount) 个会话"
        } else {
            statusText = "空闲"
            countText = "0 个会话"
        }

        accessibilityLabel = "MacIrland，\(statusText)，\(countText)"
        accentColor = topSession.map { IslandAccent.color(for: $0.status) } ?? .green
    }
}

public struct HighlightedIslandPresentation: Equatable {
    public let sessionID: TaskSession.ID
    public let status: TaskStatus
    public let titleText: String
    public let summaryText: String
    public let sourceText: String
    public let timeText: String
    public let accessibilityLabel: String
    public let accentColor: Color
    public let primaryAction: ReplyActionType?
    public let primaryActionTitle: String?

    public init?(topSession: TaskSession?) {
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
        accessibilityLabel = "MacIrland，\(titleText)，\(summaryText)，来自 \(sourceText)"
        accentColor = IslandAccent.color(for: topSession.status)
        primaryAction = visibleQuickActions.first
        primaryActionTitle = visibleQuickActions.first?.title
    }
}
