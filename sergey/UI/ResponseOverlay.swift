import SwiftUI
import AppKit

final class ResponseOverlayManager {
    static let shared = ResponseOverlayManager()
    private var window: NSWindow?

    func show(text: String, isLoading: Bool = false) {
        DispatchQueue.main.async {
            if self.window == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                window.level = .floating
                window.isOpaque = false
                window.backgroundColor = .clear
                window.center()
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                self.window = window
            }

            self.window?.contentView = NSHostingView(rootView: ResponseOverlayView(text: text, isLoading: isLoading, onClose: {
                self.hide()
            }))
            self.window?.makeKeyAndOrderFront(nil)
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
            }
            .frame(maxHeight: 300)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
        .padding(20)
    }
}
