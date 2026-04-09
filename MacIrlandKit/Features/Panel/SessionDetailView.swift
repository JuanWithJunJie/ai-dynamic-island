import SwiftUI

struct SessionDetailView: View {
    static let timelineSubtitle = "仅显示最近关键阶段。"
    static let quickActionColumns = [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)]

    static func renderedTimelineEntries(for session: TaskSession) -> [SessionHistoryEntry] {
        Array(session.timelinePreviewEntries().prefix(2))
    }

    static func visibleQuickActions(for session: TaskSession) -> [ReplyActionType] {
        session.quickActions.filter { $0 != .customText }
    }

    @Bindable var viewModel: TaskStateStore
    let session: TaskSession
    @Binding var lastActionResult: ReplyValidationResult?
    @State private var freeInputExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelSectionHeader("当前任务", subtitle: "优先处理等待你介入的步骤。")

            taskSummarySection

            detailSection("快捷回复") {
                if session.replyCapability.canSendSafely {
                    LazyVGrid(columns: Self.quickActionColumns, alignment: .leading, spacing: 8) {
                        ForEach(visibleQuickActions, id: \.self) { action in
                            Button(action.title) {
                                viewModel.draftReply = action.defaultMessage
                                lastActionResult = viewModel.performQuickAction(action, for: session)
                            }
                            .buttonStyle(.bordered)
                            .tint(IslandAccent.color(for: session.status))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text(session.replyCapability.reason)
                        .font(.caption)
                        .foregroundStyle(MacIrlandPalette.secondaryText)
                        .lineLimit(2)
                }
            }

            Divider()
                .overlay(MacIrlandPalette.subtleBorder)

            DisclosureGroup("自由输入", isExpanded: $freeInputExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    if !session.replyCapability.canSendSafely {
                        Text(session.replyCapability.reason)
                            .font(.caption)
                            .foregroundStyle(MacIrlandPalette.secondaryText)
                    }
                    TextField("输入要发送给 CLI 的回复", text: $viewModel.draftReply, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(MacIrlandPalette.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(MacIrlandPalette.border, lineWidth: 1)
                        )
                        .disabled(!session.replyCapability.canSendSafely)
                    Button("发送文本") {
                        lastActionResult = viewModel.sendDraftReply(for: session)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IslandAccent.color(for: session.status))
                    .disabled(!session.replyCapability.canSendSafely)

                    if let lastActionResult {
                        Text(lastActionResult.explanation)
                            .font(.footnote)
                            .foregroundStyle(lastActionResult.canSend ? .green : .orange)
                    }
                }
            }

            if !renderedTimelineEntries.isEmpty {
                Divider()
                    .overlay(MacIrlandPalette.subtleBorder)

                detailSection("最近关键阶段", subtitle: Self.timelineSubtitle) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(renderedTimelineEntries) { entry in
                            TimelineRow(
                                systemImage: entry.systemImage,
                                tint: entry.tint,
                                title: entry.title,
                                detail: entry.detail,
                                timeText: entry.timeText
                            )
                        }
                    }
                }
            }
        }
    }

    private var renderedTimelineEntries: [SessionHistoryEntry] {
        Self.renderedTimelineEntries(for: session)
    }

    private var visibleQuickActions: [ReplyActionType] {
        Self.visibleQuickActions(for: session)
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
                MetaChip(session.status.label, systemImage: "waveform.path.ecg")
                MetaChip(session.relativeLastActiveText, systemImage: "clock")
                if session.isAwaitingUser {
                    MetaChip("等待处理", systemImage: "hand.raised.fill", tint: .orange)
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
    let systemImage: String
    let tint: TaskStatus
    let title: String
    let detail: String
    let timeText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IslandAccent.color(for: tint))
                    .frame(width: 28, height: 28)
                    .background(IslandAccent.color(for: tint).opacity(0.16), in: Circle())

                Rectangle()
                    .fill(MacIrlandPalette.border)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(MacIrlandPalette.tertiaryText)
                }

                Text(detail)
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
