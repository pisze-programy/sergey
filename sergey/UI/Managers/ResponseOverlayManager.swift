import SwiftUI
import AppKit

final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

final class ResponseOverlayManager {
    static let shared = ResponseOverlayManager()
    private var window: NSPanel?
    var currentPlaceholder: String?

    func show(text: String, isLoading: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if text.isEmpty && self.currentPlaceholder == nil {
                self.currentPlaceholder = MessagingManager.shared.getRandomIdlePrompt()
            } else if !text.isEmpty {
                self.currentPlaceholder = nil
            }

            let windowWidth: CGFloat = 440
            let rootView = ResponseOverlayView(text: text, isLoading: isLoading, placeholder: self.currentPlaceholder, onClose: { [weak self] in
                self?.hide()
            })
            let hostingView = NSHostingView(rootView: rootView)

            let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let x = screenRect.maxX - windowWidth - 20

            let maxHeightLimit = screenRect.height / 4
            let minHeightLimit: CGFloat = 150

            if let window = self.window {
                window.contentView = hostingView
                hostingView.layoutSubtreeIfNeeded()

                let contentViewHeight = hostingView.fittingSize.height
                let targetHeight = max(minHeightLimit, min(contentViewHeight, maxHeightLimit))
                let targetY = screenRect.maxY - targetHeight - 20

                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.4
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().setFrame(NSRect(x: x, y: targetY, width: windowWidth, height: targetHeight), display: true)
                }, completionHandler: nil)
            } else {
                let startHeight: CGFloat = minHeightLimit
                let startY = screenRect.maxY + 50

                let newWindow = OverlayWindow(
                    contentRect: NSRect(x: x, y: startY, width: windowWidth, height: startHeight),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                newWindow.level = .mainMenu
                newWindow.isOpaque = false
                newWindow.backgroundColor = .clear
                newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                newWindow.contentView = hostingView
                newWindow.makeKeyAndOrderFront(nil)
                self.window = newWindow

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hostingView.layoutSubtreeIfNeeded()
                    let contentViewHeight = hostingView.fittingSize.height
                    let targetHeight = max(minHeightLimit, min(contentViewHeight, maxHeightLimit))
                    let targetY = screenRect.maxY - targetHeight - 20

                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.5
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        newWindow.animator().setFrame(NSRect(x: x, y: targetY, width: windowWidth, height: targetHeight), display: true)
                    }, completionHandler: nil)
                }
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let currentFrame = window.frame
            let targetY = screenRect.maxY + 50

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().setFrame(NSRect(x: currentFrame.origin.x, y: targetY, width: currentFrame.width, height: currentFrame.height), display: true)
            }, completionHandler: {
                window.orderOut(nil)
                self.window = nil
            })
        }
    }
}
