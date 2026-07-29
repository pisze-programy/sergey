import SwiftUI
import Combine
import AppKit

final class KeyPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.canBecomeKeyOverride = true
        self.isFloatingPanel = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.level = .mainMenu + 1
        self.hidesOnDeactivate = false
        self.backgroundColor = .clear
        self.sharingType = .none
        self.isOpaque = false
        self.ignoresMouseEvents = false
    }

    private var canBecomeKeyOverride = true
    override var canBecomeKey: Bool { canBecomeKeyOverride }
}

final class StatusOverlayManager: ObservableObject {
    static let shared = StatusOverlayManager()

    enum Layout {
        static let width: CGFloat = 350
        static let collapsedHeight: CGFloat = 55
        static let expandedHeight: CGFloat = 400
        static let paddingX: CGFloat = 20
        static let paddingY: CGFloat = 20
    }

    @Published var statusMessage: String = ""
    @Published var isActive: Bool = true
    @Published var isExpanded: Bool = false
    @Published var userInput: String = ""

    private var panel: NSPanel?

    private init() {
        setupPanel()
    }

    func showExpansion() {
        guard !isExpanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = true
        }
        updatePanelFrame()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideExpansion() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }
        updatePanelFrame()
    }

    func submitInput() {
        let input = userInput
        guard !input.isEmpty else { return }
        print("Input: \(input)")
    }

    func updateStatus(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            statusMessage = text
        }
    }

    func show() {
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func setupPanel() {
        let frame = calculateFrame(expanded: isExpanded)
        let panel = KeyPanel(contentRect: frame)
        panel.contentView = NSHostingView(rootView: StatusOverlayView().environmentObject(self))
        self.panel = panel
    }

    private func updatePanelFrame() {
        guard let panel = panel else { return }
        panel.setFrame(calculateFrame(expanded: isExpanded), display: true)
    }

    private func calculateFrame(expanded: Bool) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let height = expanded ? Layout.expandedHeight : Layout.collapsedHeight
        let x = screenFrame.maxX - Layout.width - Layout.paddingX
        let y = screenFrame.minY + Layout.paddingY
        return NSRect(x: x, y: y, width: Layout.width, height: height)
    }
}
