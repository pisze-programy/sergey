import AppKit
import Foundation
import Combine
import SwiftUI

// Borderless panel that can become key — required for reliable mouse event delivery.
// vanilla NSPanel with .borderless defaults to canBecomeKey = false on macOS.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class StatusOverlayPanel: ObservableObject {
    static let shared = StatusOverlayPanel()
    
    @Published var isExpanded: Bool = false
    @Published var userInput: String = ""
    
    private var panel: NSPanel?
    private weak var statusService: AgentStatusService?

    enum Layout {
        static let width: CGFloat = 350
        static let collapsedHeight: CGFloat = 55
        static let expandedHeight: CGFloat = 400
        static let paddingX: CGFloat = 20
        static let paddingY: CGFloat = 20
    }

    @MainActor func initialize(with statusService: AgentStatusService) {
        print("🔨 [Panel] initialize called")
        self.statusService = statusService
        
        let frame = calculateFrame(expanded: isExpanded)
        print("📐 [Panel] calculated frame: \(frame)")
        
        let newPanel = KeyPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.level = .mainMenu + 1
        newPanel.hidesOnDeactivate = false
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.ignoresMouseEvents = false
        
        let hostingView = NSHostingView(
            rootView: StatusOverlayFacadeView()
                .environmentObject(statusService)
        )
        newPanel.contentView = hostingView
        self.panel = newPanel
    }

    @MainActor func showExpansion() {
        guard !isExpanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = true
        }
        // Delay frame update to let SwiftUI settle constraints first
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            self.updatePanelFrame()
            // Re-assert key status AFTER resize so the new area receives events
            self.panel?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor func hideExpansion() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }
        // Delay frame update to let SwiftUI settle constraints first
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            self.updatePanelFrame()
            // Re-assert key status AFTER resize
            self.panel?.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor func toggleExpansion() {
        if isExpanded { hideExpansion() } else { showExpansion() }
    }

    func show() {
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
    
    @MainActor private func updatePanelFrame() {
        guard let panel = panel else { return }
        print("📐 [Panel] updatePanelFrame expanded=\(isExpanded)")
        panel.setFrame(calculateFrame(expanded: isExpanded), display: true)
    }

    @MainActor private func calculateFrame(expanded: Bool) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let height = expanded ? Layout.expandedHeight : Layout.collapsedHeight
        let x = screenFrame.maxX - Layout.width - Layout.paddingX
        let y = screenFrame.minY + Layout.paddingY
        return NSRect(x: x, y: y, width: Layout.width, height: height)
    }
}
