import AppKit
import AVFoundation
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate {
    let agent = Agent()
    let audioRecorder = AudioRecorder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        //
    }

    private func registerHotkeys() {
        HotkeyManager.shared.onVisionPressed = { [weak self] in
            _ = self?.audioRecorder.startRecording()
            self?.agent.startListening()
        }

        HotkeyManager.shared.onVisionReleased = { [weak self] in
            guard let self = self else { return }
            let audioURL = self.audioRecorder.stopRecording()
            Task {
                await self.agent.stopAndProcess(audioURL: audioURL)
            }
        }

        HotkeyManager.shared.onEscapePressed = {
            ResponseOverlayManager.shared.hide()
        }

        HotkeyManager.shared.start()
    }
}
