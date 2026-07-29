import AppKit
import Carbon

public enum HotkeyTrigger {
    case escapePressed
    case expandPressed
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    private let taskExecutor = TaskExecutor()
    private let panelManager = StatusOverlayPanel.shared
    
    private var actions: [HotkeyTrigger: () -> Void] = [
        .expandPressed: { StatusOverlayPanel.shared.toggleExpansion() }
    ]
    
    public func registerHotkeys() {
        registerAction(for: .escapePressed) { [weak self] in
            self?.taskExecutor.resetProcessing()
            self?.panelManager.hideExpansion()
        }
        
        start()
    }

    public func registerAction(for trigger: HotkeyTrigger, action: @escaping () -> Void) {
        actions[trigger] = action
    }

    func start() {
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event)
        }

        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        let ESC = 53

        if event.type == .keyDown && event.keyCode == ESC {
            DispatchQueue.main.async {
                self.actions[.escapePressed]?()
            }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == [.control, .option] {
            DispatchQueue.main.async {
                self.actions[.expandPressed]?()
            }
        }
    }
}
