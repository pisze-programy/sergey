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
    private var escapeHotKeyRef: EventHotKeyRef?

    func start() {
        // Global monitor (other apps)
        NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
        }

        // Local monitor (our app / overlay)
        NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }

        // Local monitor (our app / overlay keydown)
        NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                DispatchQueue.main.async {
                    self?.onEscapePressed?()
                }
                return nil
            }
            return event
        }

        registerGlobalEscapeHotkey()
    }

    private func registerGlobalEscapeHotkey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if hotKeyID.id == 999 {
                DispatchQueue.main.async {
                    HotkeyManager.shared.onEscapePressed?()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x53455247), id: 999)
        let status = RegisterEventHotKey(53, 0, hotKeyID, GetEventDispatcherTarget(), 0, &escapeHotKeyRef)
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
