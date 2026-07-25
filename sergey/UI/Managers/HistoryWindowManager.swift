import SwiftUI
import AppKit

final class HistoryWindowManager {
    static let shared = HistoryWindowManager()
    private var window: NSWindow?

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let hostingView = NSHostingView(rootView: HistoryView())

            let windowWidth: CGFloat = 500
            let windowHeight: CGFloat = 600

            if let window = self.window {
                window.contentView = hostingView
                window                .makeKeyAndOrderFront(nil)
            } else {
                let newWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                    styleMask: [.titled, .closable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )

                newWindow.title = "Session History"
                newWindow.isReleasedWhenClosed = false
                newWindow.level = .floating
                newWindow.center()
                newWindow.contentView = hostingView
                newWindow.makeKeyAndOrderFront(nil)
                self.window = newWindow
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            window.orderOut(nil)
            self.window = nil
        }
    }
}
