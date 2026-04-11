import SwiftUI
import MacIrlandKit

struct MenuBarStatusPresentation {
    let countText: String
    let accessibilityLabel: String
    let accentColor: Color
    let animatedStatus: AnimatedStatus

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

        if summary.completedCount > 0 && summary.runningCount == 0 && attentionCount == 0 {
            self.animatedStatus = .completed
        } else if summary.runningCount > 0 {
            self.animatedStatus = .running
        } else {
            self.animatedStatus = .idle
        }
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
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(presentation.accentColor.opacity(0.94))

                AnimatedStatusIcon(status: presentation.animatedStatus)
            }
            .frame(width: 18, height: 18)

            Text("MI")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(.white)

            Text(presentation.countText)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(minWidth: 20)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(presentation.accentColor.opacity(0.22))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(presentation.accentColor.opacity(0.42), lineWidth: 1)
                )
        }
        .frame(minWidth: 104, alignment: .leading)
        .padding(.leading, 9)
        .padding(.trailing, 10)
        .padding(.vertical, 4.5)
        .background(shellBackground, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            presentation.accentColor.opacity(0.32),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: presentation.accentColor.opacity(0.20), radius: 8, y: 1)
        .shadow(color: .black.opacity(0.24), radius: 4, y: 1)
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
