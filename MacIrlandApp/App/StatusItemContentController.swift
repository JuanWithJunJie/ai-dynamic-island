import AppKit
import SwiftUI
import MacIrlandKit

@MainActor
final class StatusItemContentController {
    private let hostingView: NSHostingView<StatusCapsuleView>

    init(session: TaskSession?) {
        let rootView = StatusCapsuleView(session: session ?? MockData.sampleFallbackSession)
        self.hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 42)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
    }

    var view: NSView {
        hostingView
    }

    func update(session: TaskSession?) {
        hostingView.rootView = StatusCapsuleView(session: session ?? MockData.sampleFallbackSession)
    }
}
