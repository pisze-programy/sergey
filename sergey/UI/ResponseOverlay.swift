import SwiftUI
import AppKit

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class ResponseOverlayManager {
    static let shared = ResponseOverlayManager()
    private var window: NSWindow?
    var currentPlaceholder: String?

    private let placeholders = [
        "How can I help?", "Ready when you are.", "Standing by.", "What's next?", 
        "Awaiting your command.", "Listening...", "All systems go.", 
        "I'm all ears.", "Ready for tasking.", "Let's get to working."
    ]

    func show(text: String, isLoading: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if text.isEmpty && self.currentPlaceholder == nil {
                self.currentPlaceholder = self.placeholders.randomElement()
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
                
                let contentViewHeight = hostingView.fittingSize.height + 32 
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
                    styleMask: [.borderless, 
                                .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                newWindow.level = .floating
                newWindow.isOpaque = false
                newWindow.backgroundColor = .clear
                newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                newWindow.contentView = hostingView
                newWindow.makeKeyAndOrderFront(nil)
                self.window = newWindow

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hostingView.layoutSubtreeIfNeeded()
                    let contentViewHeight = hostingView.fittingSize.height + 32
                    let targetHeight = max(minHeightLimit, min(contentViewHeight, maxHeightLimit))
                    let targetY = screenRect.maxY - targetHeight - 20

                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.5
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        newWindow.animator().setFrame(NSRect(x: x, y: targetY, width: windowWidth, height: targetHeight), display:
                            true)
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

struct ResponseOverlayView: View {
    let text: String
    let isLoading: Bool
    let placeholder: String?
    let onClose: () -> Void

    @State private var animatedText: String = ""

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

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    if text.isEmpty {
                        Text(animatedText)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        let attrString = makeLiteAttributedString(from: text)
                        Text(attrString)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        .task(id: text) {
            if text.isEmpty, let p = placeholder {
                animatedText = ""
                for char in p {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    animatedText.append(char)
                }
            } else {
                animatedText = text
            }
        }
    }
    
    private func makeLiteAttributedString(from text: String) -> AttributedString {
        let mutableAttrString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.utf16.count)

        var italicFont: NSFont = .systemFont(ofSize: 17)
        let descriptor = NSFont.systemFont(ofSize: 17).fontDescriptor.withSymbolicTraits(.italic)
        if let font = NSFont(descriptor: descriptor, size: 17) {
            italicFont = font
        }

        let styles: [(pattern: String, font: NSFont)] = [
            ("\\*\\*(.*?)\\*\\*", .boldSystemFont(ofSize: 17)),
            ("(?<!\\*)\\*(?!\\*)(.*?)\\*(?!\\*)", italicFont)
        ]

        for style in styles {
            let regex = try! NSRegularExpression(pattern: style.pattern, options: [])
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let m = match?.range(at: 0) {
                    mutableAttrString.addAttribute(.font, value: style.font, range: m)
                }
            }
        }

        return AttributedString(mutableAttrString)
    }
}
