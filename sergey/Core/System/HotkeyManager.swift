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
        .expandPressed: {
            print("🔥 expand hotkey fired")
            StatusOverlayPanel.shared.toggleExpansion()
        }
    ]
    
    public func registerHotkeys() {
        print("⌨️  [Hotkey] registerHotkeys called")

        print("⌨️  [Hotkey] escape action registered")
        registerAction(for: .escapePressed) { [weak self] in
            print("🔓 [Hotkey] escape action executing")
            self?.taskExecutor.resetProcessing()
            self?.panelManager.hideExpansion()
        }

        print("⏱️  [Hotkey] starting global monitors")
        start()
        print("✅ [Hotkey] registration complete")
    }

    public func registerAction(for trigger: HotkeyTrigger, action: @escaping () -> Void) {
        actions[trigger] = action
    }

    func start() {
        print("🌍 [Hotkey] adding global event monitor")
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event)
        }

        print("🏠 [Hotkey] adding local event monitor")
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        print("⚡ [Hotkey] event received: type=\(event.type.rawValue), keyCode=\(event.keyCode)")
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
