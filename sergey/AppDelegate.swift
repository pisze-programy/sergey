import AppKit
import AVFoundation
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate {
    let agent = Agent()
    let audioRecorder = AudioRecorder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        registerHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        //
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("Microphone access granted: \(granted)")
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech recognition authorization status: \(status.rawValue)")
        }
    }

    private func registerHotkeys() {
        HotkeyManager.shared.onVisionPressed = { [weak self] in
            self?.agent.captureScreenOnly()
            _ = self?.audioRecorder.startRecording()
            ResponseOverlayManager.shared.show(text: "Listening & capturing screen...", isLoading: true)
        }

        HotkeyManager.shared.onVisionReleased = { [weak self] in
            guard let self = self else { return }
            let audioURL = self.audioRecorder.stopRecording()
            Task {
                await self.agent.processVoiceAndScreen(audioURL: audioURL)
            }
        }

        HotkeyManager.shared.start()
    }
}
