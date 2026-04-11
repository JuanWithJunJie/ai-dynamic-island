import SwiftUI

public struct SettingsView: View {
    private let viewModel: TaskStateStore

    public init(viewModel: TaskStateStore) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Picker("提示音", selection: Binding(
                get: { viewModel.soundMode },
                set: { viewModel.update(soundMode: $0) }
            )) {
                ForEach(SoundMode.allCases, id: \.self) { mode in
                    Text(label(for: mode)).tag(mode)
                }
            }
        }
        .padding()
        .frame(width: 320)
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
