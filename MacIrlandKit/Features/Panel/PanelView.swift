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
                colors: [MacIrlandPalette.canvasTop, MacIrlandPalette.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    PanelHeaderView(
                        summary: viewModel.summary,
                        topSession: viewModel.topSession,
                        capabilityStatus: viewModel.capabilityStatus,
                        onRefresh: refresh
                    )
                    .padding(.bottom, 2)

                    PanelCard(tone: .elevated, padding: 22) {
                        IslandCompactView(session: viewModel.topSession)
                    }
                    .overlay(alignment: .topLeading) {
                        if let topSession = viewModel.topSession {
                            MetaChip(topSession.status.label, systemImage: "sparkles", tint: IslandAccent.color(for: topSession.status))
                                .padding(.top, -10)
                                .padding(.leading, 14)
                        }
                    }

                    PanelCard {
                        OverviewSectionView(summary: viewModel.summary)
                    }

                    PanelCard(tone: .elevated) {
                        SessionPickerView(
                            sessions: viewModel.sessions,
                            selectedSessionID: viewModel.selectedSessionID,
                            emptyStateMessage: sessionEmptyStateMessage,
                            onSelect: handleSelection
                        )
                    }

                    if let session = viewModel.selectedSession {
                        PanelCard(tone: .elevated, padding: 20) {
                            SessionDetailView(
                                viewModel: viewModel,
                                session: session,
                                lastActionResult: $lastActionResult
                            )
                        }
                    }

                    PanelCard(tone: .subdued, padding: 16) {
                        DiagnosticsSectionView(
                            session: viewModel.selectedSession,
                            capabilityStatus: viewModel.capabilityStatus,
                            observationDiagnostics: viewModel.observationDiagnostics
                        )
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private func handleSelection(_ session: TaskSession) {
        viewModel.selectSession(session)
        lastActionResult = nil
    }

    private func refresh() {
        viewModel.refresh()
        if viewModel.selectedSession == nil {
            lastActionResult = nil
        }
    }

    private var sessionEmptyStateMessage: String {
        if viewModel.capabilityStatus.observationBlocked {
            return "当前没有成功读取到 Claude Code 会话。请确认 Terminal / iTerm 自动化权限已授权，然后点击右上角刷新重试。"
        }

        if viewModel.observationDiagnostics.sessions.contains(where: { $0.recognizedCLIKind == nil }) {
            return "本轮已经读到终端 session，但还没有命中 Claude Code 识别规则。请展开下方诊断，查看 raw command / windowTitle / reason。"
        }

        return "当前没有可查看的 AI CLI 会话。"
    }
}

private struct PanelHeaderView: View {
    let summary: AppTaskSummary
    let topSession: TaskSession?
    let capabilityStatus: CapabilityStatus
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("macirland")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Capsule()
                        .fill((topSession.map { IslandAccent.color(for: $0.status) } ?? .green).opacity(0.9))
                        .frame(width: 20, height: 8)
                }

                Text(topSession?.summary ?? "统一观察 AI CLI 会话的状态、提醒与回复入口。")
                    .font(.subheadline)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    MetaChip("\(summary.totalCount) 个会话", systemImage: "square.stack.3d.up")
                    MetaChip("\(summary.attentionCount) 个待关注", systemImage: "bell.badge", tint: summary.attentionCount > 0 ? .orange : nil)
                    MetaChip(capabilityStatus.localOnlyProcessing ? "本地观察" : "扩展能力", systemImage: "sparkles")
                }
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .background(MacIrlandPalette.surfaceMuted, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(MacIrlandPalette.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}
