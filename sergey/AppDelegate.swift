import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let taskExecutor = TaskExecutor()
    let statusOverlay = StatusOverlayManager()
    
    func applicationWillFinishLaunching(_ notification: Notification) {


        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == Bundle.main.bundleIdentifier {
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SkillInitializer.shared.setup()
        HotkeyManager.shared.registerHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ResponseOverlayManager.shared.hide()
        self.taskExecutor.resetProcessing()
    }
}
