import SwiftUI

public struct IslandCompactView: View {
    private let session: TaskSession?

    public init(session: TaskSession?) {
        self.session = session
    }

    public var body: some View {
        Group {
            if let session {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        StatusSpriteView(status: session.status)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center) {
                                Text(session.sourceCLI.displayName)
                                    .font(.headline)
                                Spacer(minLength: 0)
                                StatusBadge(status: session.status)
                            }

                            Text(session.title)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)

                            Text(session.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    HStack(spacing: 10) {
                        Label(session.attentionLevel.title, systemImage: session.canReplySafely ? "arrowshape.turn.up.left.fill" : "waveform.path.ecg")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(IslandAccent.color(for: session.status))

                        Spacer(minLength: 0)

                        Text("置信度 \(Int(session.confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(IslandAccent.color(for: session.status).opacity(0.22), lineWidth: 1)
                )
            } else {
                ContentUnavailableView("No Active Tasks", systemImage: "moon.zzz", description: Text("当前没有检测到 AI CLI 活跃任务。"))
            }
        }
    }
}
