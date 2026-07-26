import AppKit
import Carbon

public enum HotkeyTrigger {
    case escapePressed
    case visionPressed
    case visionReleased
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    private let agent = Agent()
    
    private var actions: [HotkeyTrigger: () -> Void] = [:]
    private var visionActive = false
    
    public func registerHotkeys() {
        registerAction(for: .visionPressed) { [weak self] in
            self?.agent.startListening()
        }

        registerAction(for: .visionReleased) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.agent.executeRequest()
            }
        }

        registerAction(for: .escapePressed) { [weak self] in
            ResponseOverlayManager.shared.hide()
            self?.agent.resetProcessing()
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
        if event.keyCode == ESC {
            DispatchQueue.main.async {
                self.actions[.escapePressed]?()
            }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.control, .option] {
            if !visionActive {
                visionActive = true
                self.actions[.visionPressed]?()
            }
        } else if visionActive {
            visionActive = false
            self.actions[.visionReleased]?()
        }
    }
}
