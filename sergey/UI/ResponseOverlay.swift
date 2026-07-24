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

            if let window = self.window {
                window.contentView = hostingView
                let fittingSize = hostingView.fittingSize
                let height = min(max(fittingSize.height, 100), 700)
                let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let x = screenRect.maxX - windowWidth - 16
                let y = screenRect.maxY - height - 16

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: height), display: true)
                }
            } else {
                let initialFittingSize = hostingView.fittingSize
                let height = min(max(initialFittingSize.height, 100), 700)
                let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let x = screenRect.maxX - windowWidth - 16
                let y = screenRect.maxY - height - 16

                let window = OverlayWindow(
                    contentRect: NSRect(x: x, y: y, width: windowWidth, height: height),
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
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
            self.window = nil
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
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
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
            .frame(maxHeight: 620)
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
