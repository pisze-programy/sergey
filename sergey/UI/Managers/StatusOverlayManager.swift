import SwiftUI
import Combine
import AppKit

class StatusOverlayManager: ObservableObject {
    @Published var overlayText: String = ""
    @Published var isActive: Bool = true
    private var panel: NSPanel?
    
    init() {
        setupPanel()
    }
    
    private func setupPanel() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let size = CGSize(width: 350, height: 55)
        
        let x = screenFrame.maxX - size.width - 20
        let y = screenFrame.minY + 20
        
        let newPanel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newPanel.isFloatingPanel = true
        newPanel.level = .mainMenu + 1
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.ignoresMouseEvents = true
        
        let contentView = StatusOverlayView()
            .environmentObject(self)
        
        newPanel.contentView = NSHostingView(rootView: contentView)
        
        self.panel = newPanel
        newPanel.makeKeyAndOrderFront(
            nil
        )
    }
    
    func updateText(_ text: String) {
        overlayText = text
    }

    func handleMenuClick() {
        print("Menu button clicked!")
    }
    
    func show() {
        panel?.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        panel?.orderOut(nil)
    }
}
