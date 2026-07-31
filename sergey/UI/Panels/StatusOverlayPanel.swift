import AppKit
import Foundation
import Combine
import SwiftUI

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class StatusOverlayPanel: ObservableObject {
    static let shared = StatusOverlayPanel()

    @Published var isExpanded: Bool = false
    @Published var isRecording: Bool = false
    @Published var currentAudioLevel: Double = 0

    private var panel: NSPanel?
    private weak var statusService: AgentStatusService?
    private var isAnimatingFrame = false

    enum Layout {
        static let width: CGFloat = 350
        static let collapsedHeight: CGFloat = 55
        static let expandedHeight: CGFloat = 400
        static let paddingX: CGFloat = 20
        static let paddingY: CGFloat = 20
        static let cornerRadius: CGFloat = 20
    }

    @MainActor func initialize(with statusService: AgentStatusService) {
        self.statusService = statusService

        let newPanel = KeyPanel(
            contentRect: calculateFrame(expanded: isExpanded),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.ignoresMouseEvents = false
        newPanel.hasShadow = false
        newPanel.acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(
            rootView: StatusOverlayFacadeView()
                .environmentObject(statusService)
                .environmentObject(TaskQueueManager.shared)
        )
        hostingView.layer?.cornerRadius = Layout.cornerRadius
        hostingView.layer?.masksToBounds = true
        newPanel.contentView = hostingView
        self.panel = newPanel
    }

    @MainActor func showExpansion() {
        guard !isExpanded else { return }
        isExpanded = true
        animatePanelFrame()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor func hideExpansion() {
        guard isExpanded else { return }
        isExpanded = false
        animatePanelFrame()
    }

    @MainActor func toggleExpansion() {
        if isExpanded { hideExpansion() } else { showExpansion() }
    }

    func show() { panel?.makeKeyAndOrderFront(nil) }
    func hide() { panel?.orderOut(nil) }

    @MainActor private func animatePanelFrame() {
        guard !isAnimatingFrame else { return }
        isAnimatingFrame = true

        let targetFrame = calculateFrame(expanded: isExpanded)
        guard let panel = panel else { isAnimatingFrame = false; return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.completionHandler = { [weak self] in self?.isAnimatingFrame = false }
            panel.animator().setFrame(targetFrame, display: true, animate: true)
        }
    }

    @MainActor private func calculateFrame(expanded: Bool) -> NSRect {
        let screen: NSScreen?
        if let panel = panel, let panelScreen = panel.screen {
            screen = panelScreen
        } else {
            screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main
        }
        let screenFrame = screen?.visibleFrame ?? .zero
        let height = expanded ? Layout.expandedHeight : Layout.collapsedHeight
        let x = screenFrame.maxX - Layout.width - Layout.paddingX
        let y = screenFrame.minY + Layout.paddingY
        return NSRect(x: x, y: y, width: Layout.width, height: height)
    }
}
