import SwiftUI

public struct DiagnosticsSectionView: View {
    private let session: TaskSession?
    private let capabilityStatus: CapabilityStatus
    private let observationDiagnostics: ObservationDiagnostics
    private let traySessionCount: Int
    private let isTrayEligible: Bool
    private let preferredIslandSessionStatus: TaskStatus?

    public init(
        session: TaskSession?,
        capabilityStatus: CapabilityStatus,
        observationDiagnostics: ObservationDiagnostics,
        traySessionCount: Int = 0,
        isTrayEligible: Bool = false,
        preferredIslandSessionStatus: TaskStatus? = nil
    ) {
        self.session = session
        self.capabilityStatus = capabilityStatus
        self.observationDiagnostics = observationDiagnostics
        self.traySessionCount = traySessionCount
        self.isTrayEligible = isTrayEligible
        self.preferredIslandSessionStatus = preferredIslandSessionStatus
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelSectionHeader("诊断", subtitle: "保留工程视角信息，但降低视觉优先级。")

            Text(capabilityStatus.explanation)
                .font(.subheadline)
                .foregroundStyle(MacIrlandPalette.secondaryText)

            if capabilityStatus.observationBlocked {
                Text("检测到终端应用正在运行，但 MacIrland 这次没有成功读取到会话。通常是 Apple Events / 自动化权限未授权，或终端元数据暂时不可读。")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
                    )
            }

            observationReadersSection

            if !observationDiagnostics.sessions.isEmpty {
                observationSessionsSection
            }

            if let session {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MetaChip(session.status.label, systemImage: "waveform.path.ecg")
                        MetaChip("\(Int(session.confidence * 100))% · \(session.confidenceLevel.rawValue)", systemImage: "scope")
                        MetaChip(session.replyCapability.reason, systemImage: "paperplane")
                    }

                    ForEach(session.evidence.prefix(3)) { evidence in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(evidence.summary)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Text(evidence.rawSnippet)
                                .font(.caption)
                                .foregroundStyle(MacIrlandPalette.secondaryText)
                        }
                        .padding(.vertical, 8)

                        if evidence.id != session.evidence.prefix(3).last?.id {
                            Divider()
                                .overlay(MacIrlandPalette.subtleBorder)
                        }
                    }
                }
            } else {
                Text("暂无可诊断的会话。")
                    .foregroundStyle(MacIrlandPalette.secondaryText)
            }

            runtimeStateSection
        }
    }

    private var runtimeStateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelSectionHeader("运行态", subtitle: "tray / island 路由决策参考。")

            HStack(spacing: 12) {
                MetaChip(
                    "tray \(traySessionCount)",
                    systemImage: "rectangle.stack",
                    tint: traySessionCount > 1 ? .green : .gray
                )
                MetaChip(
                    isTrayEligible ? "tray 可见" : "compact",
                    systemImage: isTrayEligible ? "checkmark.circle" : "minus.circle",
                    tint: isTrayEligible ? .blue : .gray
                )
                if let status = preferredIslandSessionStatus {
                    MetaChip(
                        "island · \(status.label)",
                        systemImage: "island",
                        tint: .orange
                    )
                }
            }
        }
    }

    private var observationReadersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelSectionHeader("观测链路", subtitle: "显示本轮对 Terminal / iTerm 的读取结果。")

            if observationDiagnostics.readers.isEmpty {
                Text("当前没有 reader 诊断数据。")
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
            } else {
                ForEach(observationDiagnostics.readers) { reader in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            MetaChip(reader.readerName, systemImage: "display")
                            MetaChip(reader.fetchStatus.label, systemImage: reader.fetchStatus == .success ? "checkmark.circle" : "exclamationmark.triangle")
                            MetaChip("raw \(reader.observationCount)", systemImage: "tray.full")
                            MetaChip("recognized \(reader.recognizedEventCount)", systemImage: "sparkles")
                        }

                        Text(reader.message)
                            .font(.caption)
                            .foregroundStyle(MacIrlandPalette.secondaryText)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var observationSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelSectionHeader("原始观察", subtitle: "显示本轮 reader 读到的 windowTitle / command / tty，以及识别决定。")

            ForEach(observationDiagnostics.sessions.prefix(6)) { sessionDiagnostic in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        MetaChip(displayTerminalName(for: sessionDiagnostic.terminalAppIdentifier), systemImage: "terminal")
                        if let recognizedCLIKind = sessionDiagnostic.recognizedCLIKind {
                            MetaChip(recognizedCLIKind.displayName, systemImage: "checkmark.circle", tint: .green)
                        } else {
                            MetaChip("未识别", systemImage: "xmark.circle", tint: .orange)
                        }
                        if let inferredStatus = sessionDiagnostic.inferredStatus {
                            MetaChip(inferredStatus.label, systemImage: "waveform.path.ecg")
                        }
                    }

                    observationField("window", value: sessionDiagnostic.windowTitle)
                    observationField("command", value: sessionDiagnostic.commandLine)
                    observationField("tty", value: sessionDiagnostic.ttyIdentifier ?? "(无 tty)")
                    observationField("reason", value: sessionDiagnostic.decisionReason)
                    observationField("raw preview", value: sessionDiagnostic.transcriptPreview)
                    observationField("normalized preview", value: sessionDiagnostic.normalizedTranscriptPreview)
                    if !sessionDiagnostic.normalizedTail.isEmpty {
                        observationField("normalized tail", value: String(sessionDiagnostic.normalizedTail.prefix(200)))
                    }
                    if sessionDiagnostic.matchedSignals > 0 || sessionDiagnostic.confidence > 0 {
                        HStack(spacing: 8) {
                            MetaChip("\(sessionDiagnostic.matchedSignals) signals", systemImage: "antenna.radiowaves.left.and.right", tint: sessionDiagnostic.matchedSignals >= 2 ? .green : .gray)
                            MetaChip("\(Int(sessionDiagnostic.confidence * 100))% conf", systemImage: "scope", tint: sessionDiagnostic.confidence >= 0.78 ? .blue : .gray)
                        }
                    }
                }
                .padding(.vertical, 8)

                if sessionDiagnostic.id != observationDiagnostics.sessions.prefix(6).last?.id {
                    Divider()
                        .overlay(MacIrlandPalette.subtleBorder)
                }
            }
        }
    }

    private func observationField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MacIrlandPalette.tertiaryText)
            Text(value.isEmpty ? "(空)" : value)
                .font(.caption.monospaced())
                .foregroundStyle(MacIrlandPalette.secondaryText)
                .textSelection(.enabled)
        }
    }

    private func displayTerminalName(for identifier: String) -> String {
        switch identifier {
        case "com.apple.Terminal":
            return "Terminal"
        case "com.googlecode.iterm2":
            return "iTerm"
        default:
            return identifier
        }
    }
}
