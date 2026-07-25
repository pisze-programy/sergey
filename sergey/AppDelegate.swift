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
        SkillRegistry.shared.loadAllSkills()
        HotkeyManager.shared.registerHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ResponseOverlayManager.shared.hide()
        self.agent.resetProcessing()
    }
}
