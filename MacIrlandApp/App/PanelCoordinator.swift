import AppKit
import SwiftUI
import MacIrlandKit

@MainActor
final class PanelCoordinator {
    private let panel: NSPanel
    private let store: TaskStateStore

    init(store: TaskStateStore) {
        self.store = store
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "MacIrland"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.center()
        panel.contentView = NSHostingView(rootView: PanelView(viewModel: store))
        self.panel = panel
    }

    func showPanel() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func showPanelSelectingTopSession() {
        if let topSession = store.topSession {
            store.selectSession(topSession)
        }
        showPanel()
    }

    func showPanelSelectingSession(id: TaskSession.ID?) {
        if let id {
            store.selectSession(id: id)
        } else {
            store.selectSession(id: nil)
        }
        showPanel()
    }
}
