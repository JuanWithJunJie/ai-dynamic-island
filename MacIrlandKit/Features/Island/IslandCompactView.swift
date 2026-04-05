import SwiftUI

public struct IslandCompactView: View {
    private let session: TaskSession?

    public init(session: TaskSession?) {
        self.session = session
    }

    public var body: some View {
        Group {
            if let session {
                HStack(spacing: 12) {
                    StatusSpriteView(status: session.status)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.sourceCLI.displayName)
                                .font(.headline)
                            Spacer(minLength: 0)
                            StatusBadge(status: session.status)
                        }

                        Text(session.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(session.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ContentUnavailableView("No Active Tasks", systemImage: "moon.zzz", description: Text("当前没有检测到 AI CLI 活跃任务。"))
            }
        }
    }
}
