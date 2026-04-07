import SwiftUI

struct SessionDetailView: View {
    @Bindable var viewModel: TaskStateStore
    let session: TaskSession
    @Binding var lastActionResult: ReplyValidationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelSectionHeader("当前任务", subtitle: "把任务摘要、最新消息和回复入口分成更清晰的工作区。")

            taskSummarySection

            if !session.timelineEntries.isEmpty {
                detailSection("活动时间线", subtitle: "按时间倒序查看事件和最近消息。") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(session.timelineEntries) { entry in
                            TimelineRow(entry: entry)
                        }
                    }
                }
            }

            Divider()
                .overlay(MacIrlandPalette.subtleBorder)

            detailSection("快捷回复") {
                FlowLayout(spacing: 8) {
                    ForEach(session.quickActions, id: \.self) { action in
                        Button(action.title) {
                            if action == .customText {
                                lastActionResult = viewModel.sendDraftReply(for: session)
                            } else {
                                viewModel.draftReply = action.defaultMessage
                                lastActionResult = viewModel.performQuickAction(action, for: session)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(IslandAccent.color(for: session.status))
                    }
                }
            }

            Divider()
                .overlay(MacIrlandPalette.subtleBorder)

            detailSection("自由输入", subtitle: session.replyCapability.reason) {
                TextField("输入要发送给 CLI 的回复", text: $viewModel.draftReply, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(MacIrlandPalette.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(MacIrlandPalette.border, lineWidth: 1)
                    )
                Button("发送文本") {
                    lastActionResult = viewModel.sendDraftReply(for: session)
                }
                .buttonStyle(.borderedProminent)
                .tint(IslandAccent.color(for: session.status))

                if let lastActionResult {
                    Text(lastActionResult.explanation)
                        .font(.footnote)
                        .foregroundStyle(lastActionResult.canSend ? .green : .orange)
                }
            }
        }
    }

    private var taskSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                StatusBadge(status: session.status)
            }

            Text(session.summary)
                .font(.subheadline)
                .foregroundStyle(MacIrlandPalette.secondaryText)

            Text(session.primaryGuidanceText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(IslandAccent.color(for: session.status).opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 8) {
                MetaChip(session.sourceCLI.displayName, systemImage: "cpu")
                MetaChip(session.terminalDisplayName, systemImage: "terminal")
                MetaChip(session.relativeLastActiveText, systemImage: "clock")

                if let target = session.bridgeTarget {
                    MetaChip(target.displayName, systemImage: "paperplane")
                }
            }
        }
        .padding(16)
        .background(MacIrlandPalette.surfaceMuted.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MacIrlandPalette.subtleBorder, lineWidth: 1)
        )
    }
}

private struct TimelineRow: View {
    let entry: SessionTimelineEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: entry.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IslandAccent.color(for: entry.tint))
                    .frame(width: 28, height: 28)
                    .background(IslandAccent.color(for: entry.tint).opacity(0.16), in: Circle())

                Rectangle()
                    .fill(MacIrlandPalette.border)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(entry.timeText)
                        .font(.caption)
                        .foregroundStyle(MacIrlandPalette.tertiaryText)
                }

                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 4)
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelSectionHeader(title, subtitle: subtitle)
            content
        }
    }
}

@MainActor
private func detailSection<Content: View>(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
    DetailSection(title, subtitle: subtitle, content: content)
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}
