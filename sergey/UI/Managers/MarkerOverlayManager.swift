import SwiftUI
import AppKit
import Combine

final class MarkerOverlayManager {
    static let shared = MarkerOverlayManager()
    private var window: NSWindow?
    let state = MarkerState()
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.window != nil { return }

            let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            
            let newWindow = NSWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            newWindow.level = .screenSaver
            newWindow.isOpaque = false
            newWindow.backgroundColor = .clear
            newWindow.ignoresMouseEvents = true // Crucial: allow clicks to pass through
            newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let overlayView = MarkerOverlayView(state: self.state)
            let hostingView = NSHostingView(rootView: overlayView)
            hostingView.frame = screenFrame
            
            newWindow.contentView = hostingView
            newWindow.makeKeyAndOrderFront(nil)
            self.window = newWindow
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            self.state.clear()
            window.orderOut(nil)
            self.window = nil
        }
    }

    
    @MainActor
    func drawRect(_ rect: CGRect, color: Color = .red, lineWidth: CGFloat = 2.0, duration: TimeInterval? = nil) {
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        print("[DEBUG] MarkerOverlay - Scale: \(scale), Rect Points: \(rect)")
        let id = UUID()
        state.add(.rect(id: id, rect: rect, color: color, lineWidth: lineWidth))
        if let duration = duration {
            scheduleRemoval(id: id, after: duration)
        }
    }

    @MainActor
    func drawText(_ text: String, at point: CGPoint, color: Color = .white, duration: TimeInterval? = nil) {
        let id = UUID()
        state.add(.text(id: id, text: text, point: point, color: color))
        if let duration = duration {
            scheduleRemoval(id: id, after: duration)
        }
    }
    
    @MainActor
    func moveCursor(to point: CGPoint, duration: TimeInterval? = nil) {
        let id = UUID()
        state.add(.cursor(id: id, point: point))
        if let duration = duration {
            scheduleRemoval(id: id, after: duration)
        }
    }

    func clear() {
        state.clear()
    }
    
    private func scheduleRemoval(id: UUID, after duration: TimeInterval) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                state.remove(id: id)
            }
        }
    }
}
