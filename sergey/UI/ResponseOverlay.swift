import SwiftUI
import AppKit

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class ResponseOverlayManager {
    static let shared = ResponseOverlayManager()
    private var window: NSWindow?

    func show(text: String, isLoading: Bool = false) {
        DispatchQueue.main.async {
            let windowWidth: CGFloat = 440
            let rootView = ResponseOverlayView(text: text, isLoading: isLoading, onClose: {
                self.hide()
            })
            let hostingView = NSHostingView(rootView: rootView)

            let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let x = screenRect.maxX - windowWidth - 16

            if let window = self.window {
                window.contentView = hostingView
                let fittingSize = hostingView.fittingSize
                let height = min(max(fittingSize.height, 120), 700)
                let y = screenRect.maxY - height - 16

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: height), display: true)
                }
            } else {
                let initialFittingSize = hostingView.fittingSize
                let height = min(max(initialFittingSize.height, 120), 700)
                
                // Start above screen (off-screen)
                let startY = screenRect.maxY + 30
                let targetY = screenRect.maxY - height - 16

                let window = OverlayWindow(
                    contentRect: NSRect(x: x, y: startY, width: windowWidth, height: height),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                window.level = .floating
                window.isOpaque = false
                window.backgroundColor = .clear
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.contentView = hostingView
                window.makeKeyAndOrderFront(nil)
                self.window = window

                // Slide down animation (top to bottom)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().setFrame(NSRect(x: x, y: targetY, width: windowWidth, height: height), display: true)
                }
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            guard let window = self.window else { return }
            let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let currentFrame = window.frame
            let targetY = screenRect.maxY + 30

            // Slide up animation (bottom to top)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().setFrame(NSRect(x: currentFrame.origin.x, y: targetY, width: currentFrame.width, height: currentFrame.height), display: true)
            }, completionHandler: {
                window.orderOut(nil)
                self.window = nil
            })
        }
    }
}

struct ResponseOverlayView: View {
    let text: String
    let isLoading: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Sergey")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy text to clipboard")

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            ScrollView {
                Text(text.isEmpty ? "Listening..." : text)
                    .font(.body)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: text)
            }
            .frame(minHeight: 80, maxHeight: 520)
        }
        .padding(16)
        .background(
            ZStack {
                Color(NSColor.systemOrange).opacity(0.12)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .padding(8)
    }
}
