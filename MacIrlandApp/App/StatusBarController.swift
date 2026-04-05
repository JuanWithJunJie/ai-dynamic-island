import AppKit
import SwiftUI
import MacIrlandKit

@MainActor
final class StatusBarController {
    private let item: NSStatusItem
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.action = action

        if let button = item.button {
            button.title = "MacIrland"
            button.imagePosition = .imageLeading
            button.action = #selector(handleTap)
            button.target = self
        }
    }

    @objc private func handleTap() {
        action()
    }
}
