import SwiftUI
import AppKit

final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?
    private var frameObservers: [NSObjectProtocol] = []

    private let frameKey = "settingsWindowFrame"

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // While Settings is open, behave like a regular app: appear in Cmd+Tab
            // and the Dock, and bring the window to front with focus. When the
            // window closes we switch back to accessory (menu-bar-only) mode so the
            // overlay stays out of the app switcher.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let hostingView = NSHostingView(rootView: SettingsView())

            let windowWidth: CGFloat = 900
            let windowHeight: CGFloat = 580

            if let existing = self.window {
                existing.contentView = hostingView
                existing.makeKeyAndOrderFront(nil)
            } else {
                let newWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )

                newWindow.title = "Settings"
                newWindow.isReleasedWhenClosed = false
                // Regular window level — behaves like a normal app window (can go
                // behind other apps). The status overlay keeps its own floating
                // panel, so it stays always-on-top independently.
                newWindow.minSize = NSSize(width: 720, height: 480)
                newWindow.contentView = hostingView
                self.restoreFrameIfNeeded(for: newWindow)
                newWindow.makeKeyAndOrderFront(nil)
                self.observeFrameChanges(of: newWindow)
                self.window = newWindow
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            window.orderOut(nil)
            self.removeFrameObservers()
            self.window = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Frame persistence

    private func observeFrameChanges(of window: NSWindow) {
        removeFrameObservers()
        let center = NotificationCenter.default
        frameObservers = [
            center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                self?.persistFrame(of: window)
            },
            center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                self?.persistFrame(of: window)
            },
            // Closing via the red button returns the app to menu-bar-only mode.
            center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
        ]
    }

    private func removeFrameObservers() {
        frameObservers.forEach { NotificationCenter.default.removeObserver($0) }
        frameObservers = []
    }

    private func persistFrame(of window: NSWindow) {
        guard window.isVisible else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: frameKey)
    }

    private func restoreFrameIfNeeded(for window: NSWindow) {
        guard let saved = UserDefaults.standard.string(forKey: frameKey) else {
            window.center()
            return
        }
        let rect = NSRectFromString(saved)
        guard !rect.isEmpty else {
            window.center()
            return
        }

        // Only restore when the frame is at least partially on a visible screen,
        // otherwise fall back to centering (e.g. display was disconnected).
        let isOnScreen = NSScreen.screens.contains { $0.frame.intersects(rect) }
        if isOnScreen {
            window.setFrame(rect, display: true)
        } else {
            window.center()
        }
    }
}
