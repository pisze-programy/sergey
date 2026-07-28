import SwiftUI
import Combine
import AppKit

class StatusOverlayManager: ObservableObject {
    static let shared = StatusOverlayManager()
    @Published var statusMessage: String = ""
    @Published var isActive: Bool = true
    @Published var isExpanded: Bool = false
    private var panel: NSPanel?

    private init() {
        setupPanel()
    }

    func showExpansion() {
        if !isExpanded {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
            updatePanelFrame()
        }
    }

    func hideExpansion() {
        if isExpanded {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
            updatePanelFrame()
        }
    }

    private func updatePanelFrame() {
        guard let panel = panel else { return }
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let paddingX: CGFloat = 20
        let paddingY: CGFloat = 20

        let width: CGFloat = 350
        let height: CGFloat = isExpanded ? 400 : 55

        let x = screenFrame.maxX - width - paddingX
        let y = screenFrame.minY + paddingY

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func setupPanel() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let initialWidth: CGFloat = 350
        let initialHeight: CGFloat = 55
        let paddingX: CGFloat = 20
        let paddingY: CGFloat = 20

        let x = screenFrame.maxX - initialWidth - paddingX
        let y = screenFrame.minY + paddingY

        let newPanel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: initialWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.level = .mainMenu + 1
        newPanel.backgroundColor = .clear
        newPanel.sharingType = .none
        newPanel.isOpaque = false
        newPanel.ignoresMouseEvents = false

        let contentView = StatusOverlayView()
            .environmentObject(self)

        newPanel.contentView = NSHostingView(rootView: contentView)

        self.panel = newPanel
    }

    func updateStatus(_ text: String) {
        statusMessage = text
    }

    func show() {
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
