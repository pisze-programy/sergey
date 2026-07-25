import AppKit
import AVFoundation
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate {
    let agent = Agent()
    let audioRecorder = AudioRecorder()

    func applicationWillFinishLaunching(_ notification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == Bundle.main.bundleIdentifier {
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        //
    }

    private func registerHotkeys() {
        HotkeyManager.shared.onVisionPressed = { [weak self] in
            self?.agent.startListening()
        }

        HotkeyManager.shared.onVisionReleased = { [weak self] in
            guard let self = self else { return }
            Task {
                await self.agent.executeRequest(audioURL: nil)
            }
        }

        HotkeyManager.shared.onEscapePressed = { [weak self] in
            ResponseOverlayManager.shared.hide()
            self?.agent.resetProcessing()
        }

        HotkeyManager.shared.start()
    }
}
