import SwiftUI

public struct CompactIslandPresentation: Equatable {
    public let statusText: String
    public let countText: String
    public let secondaryText: String?
    public let accessibilityLabel: String
    public let accentColor: Color
    public let isAlert: Bool

    public init(summary: AppTaskSummary, preferredSession: TaskSession?, secondaryCount: Int, totalCountOverride: Int? = nil) {
        // Compact island shows session count, not individual session status
        // (status like "运行中"/"已完成" represents single session, not aggregate)
        if let session = preferredSession {
            accentColor = IslandAccent.color(for: session.status)
            isAlert = session.status == .alert
        } else {
            accentColor = .green
            isAlert = false
        }

        let totalCount = totalCountOverride ?? (summary.attentionCount + summary.runningCount + summary.completedCount)
        statusText = ""  // No status text in compact mode - avoids misleading aggregate status
        countText = "\(totalCount)"

        if secondaryCount > 0 {
            secondaryText = "另 \(secondaryCount) 个待处理"
        } else if isAlert {
            secondaryText = "点击查看详情"
        } else {
            secondaryText = nil
        }

        accessibilityLabel = "MacIrland，\(statusText)，\(countText)"
    }
}
