import SwiftUI

public struct PanelView: View {
    @Bindable private var viewModel: TaskStateStore
    @State private var lastActionResult: ReplyValidationResult?

    public init(viewModel: TaskStateStore) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.blue.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    IslandCompactView(session: viewModel.topSession)
                    OverviewSectionView(summary: viewModel.summary)

                    if let session = viewModel.topSession {
                        sessionSection(session)
                    }

                    if !viewModel.recentHistory.isEmpty {
                        historySection
                    }

                    DiagnosticsSectionView(session: viewModel.topSession, capabilityStatus: viewModel.capabilityStatus)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 560, minHeight: 680)
        .toolbar {
            Button("刷新") {
                viewModel.refresh()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI CLI 灵动岛")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("统一查看活跃任务、等待回复与异常状态")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                if let session = viewModel.topSession {
                    StatusBadge(status: session.status)
                    Text(session.sourceCLI.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Text(refreshLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func sessionSection(_ session: TaskSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前任务")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(session.summary)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Label(session.attentionLevel.title, systemImage: attentionSymbol(for: session))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(IslandAccent.color(for: session.status))
                        Text("优先级 \(session.priority)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                statusHighlights(for: session)

                if let target = session.bridgeTarget {
                    LabeledContent("目标会话") {
                        Text(target.displayName)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                }

                if let recoverySuggestion = session.recoverySuggestion {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("下一步建议", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Text(recoverySuggestion)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("关键事件")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    ForEach(session.recentEvents) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(IslandAccent.color(for: session.status))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            Text(event.message)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("最近消息")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    ForEach(session.recentMessages) { message in
                        Text(message.text)
                            .font(.subheadline)
                            .foregroundStyle(message.isError ? .red.opacity(0.9) : .white.opacity(0.9))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷回复")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        ForEach(session.quickActions.prefix(5), id: \.self) { action in
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("自由输入")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    TextField("输入要发送给 CLI 的回复", text: $viewModel.draftReply, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("发送文本") {
                        lastActionResult = viewModel.sendDraftReply(for: session)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IslandAccent.color(for: session.status))
                }

                if let lastActionResult {
                    Text(lastActionResult.explanation)
                        .font(.footnote)
                        .foregroundStyle(lastActionResult.canSend ? .green : .orange)
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(IslandAccent.color(for: session.status).opacity(0.14), lineWidth: 1)
            )
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近收口")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(viewModel.recentHistory) { session in
                    HStack(alignment: .top, spacing: 12) {
                        StatusSpriteView(status: session.status)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                StatusBadge(status: session.status)
                            }

                            Text(session.summary)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(2)

                            if let recoverySuggestion = session.recoverySuggestion {
                                Text(recoverySuggestion)
                                    .font(.caption)
                                    .foregroundStyle(IslandAccent.color(for: session.status))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func statusHighlights(for session: TaskSession) -> some View {
        HStack(spacing: 10) {
            highlightChip(title: session.attentionLevel.title, systemImage: attentionSymbol(for: session), tint: IslandAccent.color(for: session.status))
            highlightChip(title: "置信度 \(Int(session.confidence * 100))%", systemImage: "scope", tint: .white.opacity(0.85))
            if session.canReplySafely {
                highlightChip(title: "可安全回复", systemImage: "arrowshape.turn.up.left.fill", tint: .green)
            } else {
                highlightChip(title: "仅建议确认", systemImage: "hand.raised.fill", tint: .orange)
            }
        }
    }

    private func highlightChip(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var refreshLabel: String {
        let elapsed = max(Int(Date.now.timeIntervalSince(viewModel.lastRefreshAt)), 0)
        if elapsed < 2 {
            return "刚刚更新"
        }
        return "\(elapsed) 秒前更新"
    }

    private func attentionSymbol(for session: TaskSession) -> String {
        switch session.attentionLevel {
        case .passive:
            return "moon.stars"
        case .active:
            return "bolt.horizontal"
        case .needsReply:
            return "message.badge"
        case .warning:
            return "exclamationmark.triangle"
        }
    }
}
