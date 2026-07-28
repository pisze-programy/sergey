import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let taskExecutor = TaskExecutor()
    let statusOverlay = StatusOverlayManager.shared
    
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
        statusOverlay.show()
        startTextRotationTest()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusOverlay.hide()
        self.taskExecutor.resetProcessing()
    }

    private func startTextRotationTest() {
        let sampleTexts = [
            "",
            "Short",
            "A bit longer text",
            "This is a significantly longer status message to test width expansion",
            "Testing truncation here as well",
            "🚀 Working!"
        ]
        
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.statusOverlay.statusMessage = sampleTexts[index % sampleTexts.count]
            self.statusOverlay.isActive.toggle()
            index += 1
        }
    }
}

extension ProcessInfo {
    func tryProcessIdentifier() -> ProcessInfo { self }
}
