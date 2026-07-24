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
        NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
        }

        NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.onEscapePressed?()
            }
        }
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        let fn = flags.contains(.function)
        let shift = flags.contains(.shift)
        let control = flags.contains(.control)

        if fn && control {
            if !voiceActive {
                voiceActive = true
                onVoicePressed?()
            }
        } else if voiceActive {
            voiceActive = false
            onVoiceReleased?()
        }

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