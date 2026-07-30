import SwiftUI
import AppKit

final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let hostingView = NSHostingView(rootView: SettingsView())

            let windowWidth: CGFloat = 900
            let windowHeight: CGFloat = 580

            if let existing = self.window {
                existing.contentView = hostingView
                existing.makeKeyAndOrderFront(nil)
            } else {
                let newWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                    styleMask: [.titled, .closable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )

                newWindow.title = "Settings"
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
