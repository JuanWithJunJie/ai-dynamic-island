import SwiftUI

public struct SettingsView: View {
    private let viewModel: TaskStateStore

    public init(viewModel: TaskStateStore) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("原型模式") {
                Picker("观察源", selection: Binding(
                    get: { viewModel.observationMode },
                    set: { viewModel.update(observationMode: $0) }
                )) {
                    ForEach(ObservationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(viewModel.observationMode.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("自动刷新")
                        Spacer()
                        Text(viewModel.autoRefreshLabel)
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { viewModel.autoRefreshInterval },
                            set: { viewModel.update(autoRefreshInterval: $0) }
                        ),
                        in: 2 ... 12,
                        step: 1
                    )
                }

                Button("立即刷新") {
                    viewModel.refresh()
                }
            }

            Section("提醒") {
                Picker("提示音", selection: Binding(
                    get: { viewModel.soundMode },
                    set: { viewModel.update(soundMode: $0) }
                )) {
                    ForEach(SoundMode.allCases, id: \.self) { mode in
                        Text(label(for: mode)).tag(mode)
                    }
                }
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func label(for mode: SoundMode) -> String {
        switch mode {
        case .all:
            return "全部开启"
        case .criticalOnly:
            return "仅关键提示"
        case .mute:
            return "静音"
        }
    }
}
