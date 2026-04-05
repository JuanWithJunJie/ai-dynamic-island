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

            if let session = viewModel.topSession {
                VStack(alignment: .trailing, spacing: 6) {
                    StatusBadge(status: session.status)
                    Text(session.sourceCLI.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
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

                if let target = session.bridgeTarget {
                    LabeledContent("目标会话") {
                        Text(target.displayName)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
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
        }
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
