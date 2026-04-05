import AppKit
import MacIrlandKit

@MainActor
final class StatusBarController {
    private let item: NSStatusItem
    private let action: () -> Void
    private let contentController: StatusItemContentController

    init(session: TaskSession?, action: @escaping () -> Void) {
        self.item = NSStatusBar.system.statusItem(withLength: 340)
        self.action = action
        self.contentController = StatusItemContentController(session: session)

        if let button = item.button {
            button.title = ""
            button.image = nil
            button.addSubview(contentController.view)
            contentController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentController.view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                contentController.view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                contentController.view.topAnchor.constraint(equalTo: button.topAnchor),
                contentController.view.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            button.action = #selector(handleTap)
            button.target = self
        }
    }

    func update(session: TaskSession?) {
        contentController.update(session: session)
    }

    @objc private func handleTap() {
        action()
    }
}
