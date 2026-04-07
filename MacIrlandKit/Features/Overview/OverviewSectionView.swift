import SwiftUI

public struct OverviewSectionView: View {
    private let summary: AppTaskSummary

    public init(summary: AppTaskSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelSectionHeader("任务总览", subtitle: "当前面板里的活动与完成态分布。")

            HStack(spacing: 10) {
                MetricCard(title: "运行中", value: summary.runningCount, tint: .blue)
                MetricCard(title: "等待用户", value: summary.waitingCount, tint: .orange)
                MetricCard(title: "已完成", value: summary.completedCount, tint: .green)
                MetricCard(title: "异常", value: summary.alertCount, tint: .red)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(MacIrlandPalette.secondaryText)
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Capsule()
                .fill(tint.opacity(0.88))
                .frame(width: 22, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.10), lineWidth: 1)
        )
    }
}
