import SwiftUI
import MacIrlandKit

struct MenuBarStatusPresentation {
    let countText: String
    let accessibilityLabel: String
    let accentColor: Color

    init(summary: AppTaskSummary, topSession: TaskSession?) {
        let attentionCount = summary.attentionCount
        if attentionCount > 0 {
            self.countText = "\(attentionCount)"
            self.accessibilityLabel = "MacIrland，\(attentionCount) 个需要关注"
        } else if summary.runningCount > 0 {
            self.countText = "\(summary.runningCount)"
            self.accessibilityLabel = "MacIrland，\(summary.runningCount) 个运行中"
        } else if summary.completedCount > 0 {
            self.countText = "\(summary.completedCount)"
            self.accessibilityLabel = "MacIrland，\(summary.completedCount) 个已完成"
        } else {
            self.countText = "0"
            self.accessibilityLabel = "MacIrland，当前没有活动会话"
        }

        self.accentColor = topSession.map { IslandAccent.color(for: $0.status) } ?? .green
    }
}

struct MenuBarStatusLabel: View {
    let summary: AppTaskSummary
    let topSession: TaskSession?

    private var presentation: MenuBarStatusPresentation {
        MenuBarStatusPresentation(summary: summary, topSession: topSession)
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)

            Text("MI")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))

            Text(presentation.countText)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(presentation.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .padding(.leading, 8)
        .padding(.trailing, 9)
        .padding(.vertical, 4)
        .background(shellBackground, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 4, y: 1)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var shellBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.10, blue: 0.14),
                Color(red: 0.05, green: 0.06, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
