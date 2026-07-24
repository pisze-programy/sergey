import SwiftUI
import AppKit

// MARK: - Highlight Overlay Manager (Unintegrated for future use)

final class HighlightOverlayManager {
    static let shared = HighlightOverlayManager()
    private var window: NSWindow?

    func showHighlight(rect: CGRect, label: String = "") {
        DispatchQueue.main.async {
            self.hide()

            let window = NSWindow(
                contentRect: rect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true

            window.contentView = NSHostingView(rootView: HighlightView(label: label))
            window.setFrame(rect, display: true)
            window.makeKeyAndOrderFront(nil)
            self.window = window
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
            self.window = nil
        }
    }
}

struct HighlightView: View {
    let label: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(Color.orange, lineWidth: 3)
                .background(Color.orange.opacity(0.2))
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .cornerRadius(4)
                    .offset(y: -24)
            }
        }
    }
}
