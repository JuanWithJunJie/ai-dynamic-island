import SwiftUI

public struct IslandMultiSessionTrayView: View {
    @Bindable var store: TaskStateStore
    let onSessionSelected: (TaskSession.ID) -> Void
    let onHoverChanged: (Bool) -> Void

    public init(
        store: TaskStateStore,
        onSessionSelected: @escaping (TaskSession.ID) -> Void,
        onHoverChanged: @escaping (Bool) -> Void
    ) {
        self.store = store
        self.onSessionSelected = onSessionSelected
        self.onHoverChanged = onHoverChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header pill
            HStack {
                Text("所有会话")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                Spacer()
                Text("\(store.traySessions.count) 个")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
                .background(MacIrlandPalette.border.opacity(0.4))

            // Session rows from traySessions (filtered, relevant sessions only)
            ForEach(store.traySessions.prefix(5)) { session in
                TraySessionRow(session: session)
                    .onTapGesture {
                        onSessionSelected(session.id)
                    }
            }

            if store.traySessions.count > 5 {
                Text("还有 \(store.traySessions.count - 5) 个会话")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
                    .padding(.top, 4)
            }
        }
        .frame(width: 380)
        .background(MacIrlandPalette.islandSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(MacIrlandPalette.islandSubtleBorder, lineWidth: 1)
        )
        .onHover { isHovering in
            onHoverChanged(isHovering)
        }
    }
}

struct TraySessionRow: View {
    let session: TaskSession

    var body: some View {
        HStack(spacing: 10) {
            AnimatedStatusIcon(status: session.status.animatedStatus)
                .scaleEffect(0.7)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(session.sourceCLI.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.relativeLastActiveText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)

                Text(session.status.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(IslandAccent.color(for: session.status))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            rowBackgroundColor
        )
        .contentShape(Rectangle())
    }

    private var rowBackgroundColor: Color {
        if session.status == .alert {
            return Color.red.opacity(0.12)
        }
        if session.status.needsAttention {
            return IslandAccent.color(for: session.status).opacity(0.06)
        }
        return Color.clear
    }
}
