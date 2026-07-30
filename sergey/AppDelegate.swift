import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let taskExecutor = TaskExecutor()
    private var taskDispatcher: TaskDispatcher?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == Bundle.main.bundleIdentifier {
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.registerHotkeys()

        let agentService = AgentStatusService.shared
        let panelManager = StatusOverlayPanel.shared
        
        panelManager.initialize(with: agentService)
        panelManager.show()
        
        taskDispatcher = TaskDispatcher.shared
        taskDispatcher?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatusOverlayPanel.shared.hide()
        self.taskExecutor.resetProcessing()
        taskDispatcher?.stop()
    }
}
