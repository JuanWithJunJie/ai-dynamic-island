import AppKit
import SwiftUI
import MacIrlandKit

@MainActor
final class PanelCoordinator {
    private let panel: NSPanel

    init(store: TaskStateStore) {
        let hostingView = NSHostingView(rootView: PanelView(viewModel: store))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "MacIrland"
        panel.center()
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.contentView = hostingView
        self.panel = panel
    }

    func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
