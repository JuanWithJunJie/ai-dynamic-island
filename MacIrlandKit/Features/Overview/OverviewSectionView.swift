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
                .foregroundStyle(.white)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                MetricCard(title: "运行中", value: summary.runningCount, tint: .blue, systemImage: "bolt.fill")
                MetricCard(title: "等待用户", value: summary.waitingCount, tint: .orange, systemImage: "message.badge.fill")
                MetricCard(title: "已完成", value: summary.completedCount, tint: .green, systemImage: "checkmark.circle.fill")
                MetricCard(title: "异常", value: summary.alertCount, tint: .red, systemImage: "exclamationmark.triangle.fill")
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
