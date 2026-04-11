import AppKit
import MacIrlandKit
import Observation

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let store: TaskStateStore
    private let action: () -> Void

    init(store: TaskStateStore, action: @escaping () -> Void) {
        self.store = store
        self.action = action
        // On notched displays, wide third-party status items are the first ones to get
        // crowded into the notch edge. Keep this item intentionally compact.
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        observeStore()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .black)
        let image = NSImage(
            systemSymbolName: "terminal.fill",
            accessibilityDescription: "MacIrland"
        )?.withSymbolConfiguration(symbolConfiguration)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp])
        refreshAppearance()
    }

    private func observeStore() {
        withObservationTracking {
            _ = store.summary
            _ = store.topSession
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.refreshAppearance()
                self?.observeStore()
            }
        }
    }

    private func refreshAppearance() {
        guard let button = statusItem.button else {
            return
        }

        let presentation = MenuBarStatusPresentation(summary: store.summary, topSession: store.topSession)
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = "\(presentation.accessibilityLabel)。顶部 island 会在高优先级会话时展开，菜单栏入口仍可作为 fallback。"
    }

    @objc
    private func handleClick() {
        action()
    }
}
