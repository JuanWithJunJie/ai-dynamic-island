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

            // === All Sessions List ===
            HoverExpandSessionList(
                sessions: store.hoverExpandSessions,
                preferredSessionID: preferredSessionID,
                onJumpToSession: onJumpToSession,
                onHoverChanged: onHoverChanged
            )
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
                        Text(detailTitle)
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
                        if let terminalLabel = terminalTypeLabel {
                            Text(terminalLabel.text)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(terminalLabel.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(terminalLabel.bg.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                        }
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

            // Continue button (if applicable and not completed)
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

                    Spacer()
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

    private var detailTitle: String {
        // For iTerm2, sessionName is the actual session name (e.g., "PlanApp")
        // For Terminal, sessionName may be empty, fall back to path extraction
        // Extract project name (same logic as rowTitle)
        let projectName: String
        if let range = session.title.range(of: ": ") {
            projectName = String(session.title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if !session.title.isEmpty && session.title != "Claude Code" && !session.title.hasPrefix("Running Claude Code") && !session.title.hasPrefix("Completed Claude Code") {
            projectName = session.title
        } else if !session.identity.sessionName.isEmpty && session.identity.sessionName != "⠂ Claude Code" && session.identity.sessionName != "✳ Claude Code" && !session.identity.sessionName.contains("Claude Code") {
            projectName = session.identity.sessionName
        } else {
            let components = session.identity.commandLine.split(separator: "/")
            if let last = components.last {
                projectName = String(last).trimmingCharacters(in: .whitespaces)
            } else {
                projectName = session.title
            }
        }
        // Add status indicator prefix
        let indicator: String
        switch session.status {
        case .running:
            indicator = "● "
        case .waitingInput, .replyAvailable:
            indicator = "◐ "
        case .completed:
            indicator = "✓ "
        case .alert, .failed:
            indicator = "✕ "
        default:
            indicator = ""
        }
        return indicator + projectName
    }

    private var terminalTypeLabel: (text: String, color: Color, bg: Color)? {
        let identifier = session.identity.terminalAppIdentifier
        switch identifier {
        case "com.apple.Terminal":
            return (text: "Terminal", color: MacIrlandPalette.mockupOrange, bg: MacIrlandPalette.mockupOrange)
        case "com.googlecode.iterm2":
            return (text: "iTerm2", color: MacIrlandPalette.mockupBlue, bg: MacIrlandPalette.mockupBlue)
        default:
            return nil
        }
    }

    private var sessionDetailSubtitle: String {
        let tty = session.identity.ttyIdentifier ?? "ttys"
        let base: String
        switch session.status {
        case .running:
            base = "运行中"
        case .waitingInput:
            base = "等待输入"
        case .replyAvailable:
            base = "可回复"
        case .completed:
            base = "已完成"
        case .alert:
            base = "异常"
        default:
            base = session.status.label
        }
        return "\(base) · \(tty)"
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
                Text(rowTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(rowSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
                    .lineLimit(1)
            }

            Spacer()

            if let terminalLabel = terminalTypeLabel {
                Text(terminalLabel.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(terminalLabel.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(terminalLabel.bg.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            }

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

    private var terminalTypeLabel: (text: String, color: Color, bg: Color)? {
        let identifier = session.identity.terminalAppIdentifier
        switch identifier {
        case "com.apple.Terminal":
            return (text: "Terminal", color: MacIrlandPalette.mockupOrange, bg: MacIrlandPalette.mockupOrange)
        case "com.googlecode.iterm2":
            return (text: "iTerm2", color: MacIrlandPalette.mockupBlue, bg: MacIrlandPalette.mockupBlue)
        default:
            return nil
        }
    }

    private var rowTitle: String {
        // For iTerm2, sessionName is the actual session name (e.g., "PlanApp")
        // Prefer hook-derived title (project name from cwd) over sessionName
        // Hook-derived title looks like "PlanApp" or extracted from "Running Claude Code terminal session: macirland"
        if let range = session.title.range(of: ": ") {
            let extracted = String(session.title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !extracted.isEmpty && extracted != "Claude Code" {
                return extracted
            }
        }
        // If hook-derived title is valid (not "Claude Code" and not empty), use it
        if !session.title.isEmpty && session.title != "Claude Code" && !session.title.hasPrefix("Running Claude Code") && !session.title.hasPrefix("Completed Claude Code") {
            return session.title
        }
        // Fall back to sessionName only if title didn't yield a valid project name
        if !session.identity.sessionName.isEmpty && session.identity.sessionName != "⠂ Claude Code" && session.identity.sessionName != "✳ Claude Code" && !session.identity.sessionName.contains("Claude Code") {
            return session.identity.sessionName
        }
        let components = session.identity.commandLine.split(separator: "/")
        if let last = components.last {
            return String(last).trimmingCharacters(in: .whitespaces)
        }
        return session.title
    }

    private var rowSubtitle: String {
        session.identity.ttyIdentifier ?? "ttys"
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
