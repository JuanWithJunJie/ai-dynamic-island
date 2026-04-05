import SwiftUI

public struct OverviewSectionView: View {
    private let summary: AppTaskSummary

    public init(summary: AppTaskSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任务总览")
                .font(.headline)

            HStack(spacing: 12) {
                MetricCard(title: "运行中", value: summary.runningCount, tint: .blue, systemImage: "bolt.fill")
                MetricCard(title: "等待用户", value: summary.waitingCount, tint: .orange, systemImage: "message.badge.fill")
                MetricCard(title: "已完成", value: summary.completedCount, tint: .green, systemImage: "checkmark.circle.fill")
                MetricCard(title: "异常", value: summary.alertCount, tint: .red, systemImage: "exclamationmark.triangle.fill")
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
