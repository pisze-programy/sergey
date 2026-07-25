import AppKit
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onVoicePressed: (() -> Void)?
    var onVoiceReleased: (() -> Void)?

    var onVisionPressed: (() -> Void)?
    var onVisionReleased: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    private var voiceActive = false
    private var visionActive = false

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
        // ESC key
        if event.keyCode == 53 {
            DispatchQueue.main.async {
                self.onEscapePressed?()
            }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let fn = flags.contains(.function)
        let shift = flags.contains(.shift)
        
        if fn && shift {
            if !visionActive {
                visionActive = true
                onVisionPressed?()
            }
        } else if visionActive {
            visionActive = false
            onVisionReleased?()
        }
    }
}
