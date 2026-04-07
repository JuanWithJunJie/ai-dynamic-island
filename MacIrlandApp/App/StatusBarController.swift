import AppKit

@available(*, deprecated, message: "Menu bar presence is now owned by MenuBarExtra in MacIrlandApp.swift")
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.title = "MI"
        button.toolTip = "MacIrland"
        button.target = self
        button.action = #selector(handleClick)
    }

    @objc
    private func handleClick() {
        action()
    }
}
