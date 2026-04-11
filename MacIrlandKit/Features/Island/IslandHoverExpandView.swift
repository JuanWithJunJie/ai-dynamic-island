import SwiftUI

/// Option B hover expand layout per mockup:
/// - Upper: current attention session detail (simplified card)
/// - Lower: all session list with click-to-jump
public struct IslandHoverExpandView: View {
    @Bindable var store: TaskStateStore
    let preferredSessionID: TaskSession.ID?
    let onJumpToSession: (TaskSession.ID) -> Void
    let onHoverChanged: (Bool) -> Void
    let onContinueAction: () -> Void
    @State private var isPanelHovered = false

    public init(
        store: TaskStateStore,
        preferredSessionID: TaskSession.ID?,
        onJumpToSession: @escaping (TaskSession.ID) -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onContinueAction: @escaping () -> Void
    ) {
        self.store = store
        self.preferredSessionID = preferredSessionID
        self.onJumpToSession = onJumpToSession
        self.onHoverChanged = onHoverChanged
        self.onContinueAction = onContinueAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            // === Status Strip ===
            HoverExpandStatusStrip(
                store: store,
                isHovered: isPanelHovered,
                onSoundToggle: toggleSound
            )

            Divider()
                .background(MacIrlandPalette.border.opacity(0.4))

            // === Session Detail (preferred island session) ===
            if let session = store.hoverExpandPrimarySession {
                HoverExpandSessionDetail(
                    session: session,
                    onJumpToSession: onJumpToSession,
                    onContinue: onContinueAction,
                    onHoverChanged: onHoverChanged
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .onHover { hovering in
                    onHoverChanged(hovering)
                }

                Divider()
                    .background(MacIrlandPalette.border.opacity(0.4))
            }

            // === Session List ===
            if !store.hoverExpandSecondarySessions.isEmpty {
                HoverExpandSessionList(
                    sessions: store.hoverExpandSecondarySessions,
                    preferredSessionID: preferredSessionID,
                    onJumpToSession: onJumpToSession,
                    onHoverChanged: onHoverChanged
                )
            }
        }
        .frame(width: 520)
        .background(MacIrlandPalette.mockupPanelBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(MacIrlandPalette.subtleBorder, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPanelHovered = hovering
            }
        }
    }

    private func toggleSound() {
        withObservationTracking {
            let current = store.soundMode
            let newMode: SoundMode = (current == .mute) ? .all : .mute
            store.soundMode = newMode
        } onChange: { }
    }
}

// MARK: - Status Strip

private struct HoverExpandStatusStrip: View {
    @Bindable var store: TaskStateStore
    let isHovered: Bool
    let onSoundToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusDotColor, radius: 3)

            Text(statusTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            // Control area: sound toggle | count
            HStack(spacing: 8) {
                SoundToggleButton(isOn: store.soundMode != .mute)
                    .opacity(isHovered ? 1 : 0)
                    .onTapGesture {
                        onSoundToggle()
                    }

                Text("\(store.hoverExpandSessionCount) 个会话")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(MacIrlandPalette.mockupStatusStripBg)
    }

    private var statusDotColor: Color {
        guard let session = store.hoverExpandPrimarySession else {
            return MacIrlandPalette.mockupGreen
        }
        return accentColor(for: session.status)
    }

    private var statusTitle: String {
        if let session = store.hoverExpandPrimarySession {
            return session.title
        }
        return "MacIrland"
    }

    private func accentColor(for status: TaskStatus) -> Color {
        switch status {
        case .running: return MacIrlandPalette.mockupGreen
        case .waitingInput, .replyAvailable, .completed: return MacIrlandPalette.mockupOrange
        case .alert, .failed: return .red
        default: return .gray
        }
    }
}

// MARK: - Sound Toggle Button (SF Symbol-based)

private struct SoundToggleButton: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Image(systemName: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isOn ? Color.white.opacity(0.85) : MacIrlandPalette.tertiaryText)
        }
        .frame(width: 26, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isOn ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Session Detail

private struct HoverExpandSessionDetail: View {
    let session: TaskSession
    let onJumpToSession: (TaskSession.ID) -> Void
    let onContinue: () -> Void
    let onHoverChanged: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main row - wrapped in button for reliable tap handling
            Button(action: {
                print("DEBUG: HoverExpandSessionDetail button tapped, session.id=\(session.id)")
                onJumpToSession(session.id)
            }) {
                HStack(alignment: .center, spacing: 10) {
                    detailIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(sessionDetailSubtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        StatusChip(status: session.status)
                        Text("↗ 跳转")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MacIrlandPalette.mockupBlue)
                        Text(session.relativeLastActiveText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.28, green: 0.28, blue: 0.29))
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Recent input bubble (if available)
            if let recentMessage = session.recentMessages.first, !recentMessage.text.isEmpty {
                HStack(spacing: 6) {
                    Text("Input")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.39, green: 0.39, blue: 0.42))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(MacIrlandPalette.mockupPanelBg, in: Capsule())

                    Text(recentMessage.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.82, green: 0.82, blue: 0.84))
                        .lineLimit(1)
                }
                .padding(8)
                .background(MacIrlandPalette.mockupPanelBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Events timeline
            HoverExpandEventsTimeline(session: session)

            // Continue button (if applicable and not completed)
            // Don't show continue button for completed sessions - only show when hovering
            if session.replyCapability.canSendSafely && session.status != .completed {
                HStack(spacing: 10) {
                    Button(action: onContinue) {
                        Text("继续")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(MacIrlandPalette.mockupOrange, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("发送成功")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MacIrlandPalette.mockupGreen)

                    Text("点击主卡片 → 跳转 Terminal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MacIrlandPalette.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var detailIcon: some View {
        let color = iconColor
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)

            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
        }
    }

    private var iconColor: Color {
        switch session.status {
        case .running: return MacIrlandPalette.mockupGreen
        case .waitingInput, .replyAvailable, .completed: return MacIrlandPalette.mockupOrange
        case .alert, .failed: return .red
        default: return .gray
        }
    }

    private var sessionDetailSubtitle: String {
        switch session.status {
        case .running:
            return "运行中 · \(session.sourceCLI.displayName)"
        case .waitingInput:
            return "等待输入 · \(session.sourceCLI.displayName)"
        case .replyAvailable:
            return "可回复 · \(session.sourceCLI.displayName)"
        case .completed:
            return "已完成 · \(session.sourceCLI.displayName)"
        case .alert:
            return "异常 · \(session.sourceCLI.displayName)"
        default:
            return "\(session.status.label) · \(session.sourceCLI.displayName)"
        }
    }
}

// MARK: - Events Timeline

private struct HoverExpandEventsTimeline: View {
    let session: TaskSession

    var body: some View {
        HStack(spacing: 6) {
            Text("Events")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.28, green: 0.28, blue: 0.29))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(MacIrlandPalette.mockupPanelBg, in: Capsule())

            HStack(spacing: 4) {
                ForEach(Array(timelineEvents.enumerated()), id: \.offset) { index, event in
                    Circle()
                        .fill(event.color)
                        .frame(width: 6, height: 6)

                    Text(event.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 0.39, green: 0.39, blue: 0.42))

                    if index < timelineEvents.count - 1 {
                        Text("→")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(red: 0.23, green: 0.23, blue: 0.24))
                    }
                }
            }
        }
        .padding(0)
    }

    private var timelineEvents: [(text: String, color: Color)] {
        // Show last 3 events from the session
        var events: [(text: String, color: Color)] = []

        for entry in session.recentMessages.prefix(3) {
            if entry.kind == .user {
                events.append((text: "输入", color: MacIrlandPalette.mockupGreen))
            } else {
                events.append((text: "回复", color: MacIrlandPalette.mockupOrange))
            }
        }

        if events.isEmpty {
            events.append((text: "开始", color: MacIrlandPalette.mockupOrange))
        }

        return events
    }
}

// MARK: - Status Chip

private struct StatusChip: View {
    let status: TaskStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(chipColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.15), in: Capsule())
    }

    private var chipColor: Color {
        switch status {
        case .running:
            return MacIrlandPalette.mockupGreen
        case .waitingInput, .replyAvailable, .completed:
            return MacIrlandPalette.mockupOrange
        case .alert, .failed:
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Session List

private struct HoverExpandSessionList: View {
    let sessions: [TaskSession]
    let preferredSessionID: TaskSession.ID?
    let onJumpToSession: (TaskSession.ID) -> Void
    let onHoverChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("其他会话")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.58))

                Spacer()

                Text("\(sessions.count) 个")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .background(MacIrlandPalette.border.opacity(0.4))

            // Rows
            ForEach(sessions.prefix(5)) { session in
                HoverExpandSessionRow(
                    session: session,
                    isPreferred: session.id == preferredSessionID,
                    onJumpToSession: onJumpToSession
                )

                if session.id != sessions.prefix(5).last?.id {
                    Divider()
                        .background(MacIrlandPalette.border.opacity(0.3))
                        .padding(.horizontal, 0)
                }
            }
        }
        .onHover { isHovering in
            onHoverChanged(isHovering)
        }
    }
}

// MARK: - Session Row

private struct HoverExpandSessionRow: View {
    let session: TaskSession
    let isPreferred: Bool
    let onJumpToSession: (TaskSession.ID) -> Void
    @State private var isHoveringRow = false

    var body: some View {
        HStack(spacing: 10) {
            rowIcon

            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(session.sourceCLI.displayName) · \(session.identity.ttyIdentifier ?? "ttys")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.status.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(rowStatusColor)

                Text("↗ 跳转")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isHoveringRow ? MacIrlandPalette.mockupBlue : MacIrlandPalette.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(rowBackgroundColor)
        .onHover { hovering in
            isHoveringRow = hovering
        }
        .onTapGesture {
            onJumpToSession(session.id)
        }
    }

    @ViewBuilder
    private var rowIcon: some View {
        let color = iconColor
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 26, height: 26)

            switch session.status {
            case .running:
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            case .waitingInput, .replyAvailable, .completed:
                Text("✓")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
            default:
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var iconColor: Color {
        switch session.status {
        case .running: return MacIrlandPalette.mockupGreen
        case .waitingInput, .replyAvailable, .completed: return MacIrlandPalette.mockupOrange
        case .alert, .failed: return .red
        default: return .gray
        }
    }

    private var rowStatusColor: Color {
        switch session.status {
        case .running: return MacIrlandPalette.mockupGreen
        case .waitingInput, .replyAvailable, .completed: return MacIrlandPalette.mockupOrange
        case .alert, .failed: return .red
        default: return .gray
        }
    }

    private var rowBackgroundColor: Color {
        if session.status == .alert {
            return Color.red.opacity(0.12)
        }
        if isPreferred {
            return MacIrlandPalette.mockupOrange.opacity(0.06)
        }
        return Color.clear
    }
}
