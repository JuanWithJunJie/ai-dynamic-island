import SwiftUI

public struct StatusCapsuleView: View {
    private let session: TaskSession

    public init(session: TaskSession) {
        self.session = session
    }

    public var body: some View {
        HStack(spacing: 10) {
            StatusSpriteView(status: session.status)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(IslandAccent.color(for: session.status))
                        .frame(width: 10, height: 10)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(session.attentionLevel.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(session.sourceCLI.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(Int(session.confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(IslandAccent.color(for: session.status))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 320)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(IslandAccent.color(for: session.status).opacity(0.25), lineWidth: 1)
        )
        .help(session.summary)
    }
}
