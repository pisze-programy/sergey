import AppKit
import Carbon

public enum HotkeyTrigger {
    case escapePressed
    case expandPressed
    case recordingToggled
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    private let taskExecutor = TaskExecutor()
    private let panelManager = StatusOverlayPanel.shared

    private var isShortcutRecording = false
    private var rightCmdDown = false
    private var rightOptDown = false

    private var actions: [HotkeyTrigger: () -> Void] = [
        .expandPressed: { StatusOverlayPanel.shared.toggleExpansion() },
        .recordingToggled: { DictationOrchestrator.shared.toggleRecording() }
    ]

    public func registerHotkeys() {
        registerAction(for: .escapePressed) { [weak self] in
            self?.panelManager.hideExpansion()
        }
        start()
    }

    public func registerAction(for trigger: HotkeyTrigger, action: @escaping () -> Void) {
        actions[trigger] = action
    }

    func start() {
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handle(event)
        }

        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            let shouldSuppress = self?.shouldConsumeEvent(event) == true
            self?.handle(event)
            return shouldSuppress ? nil : event
        }
    }

    private func shouldConsumeEvent(_ event: NSEvent) -> Bool { false }

    private func handle(_ event: NSEvent) {
        let ESC: CGKeyCode = 53

        if event.type == .keyDown && event.keyCode == ESC {
            DispatchQueue.main.async { self.actions[.escapePressed]?() }
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if (event.type == .flagsChanged || event.type == .keyDown) && flags == [.control, .option] {
            DispatchQueue.main.async { self.actions[.expandPressed]?() }
            return
        }

        if event.type == .flagsChanged {
            if event.keyCode == 54 {
                rightCmdDown = flags.contains(.command)
            } else if event.keyCode == 61 {
                rightOptDown = flags.contains(.option)
            }

            if rightCmdDown && rightOptDown {
                if !isShortcutRecording {
                    isShortcutRecording = true
                    DictationOrchestrator.shared.startRecording()
                }
            } else if isShortcutRecording {
                isShortcutRecording = false
                rightCmdDown = false
                rightOptDown = false
                DictationOrchestrator.shared.stopAndTranscribe()
            }
        }
    }
}
