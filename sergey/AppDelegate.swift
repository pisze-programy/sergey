import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let taskExecutor = TaskExecutor()
    
    override init() {
        super.init()
        print("✅ [AppDelegate] init completed")
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        print("⏳ [AppDelegate] applicationWillFinishLaunching")
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == Bundle.main.bundleIdentifier {
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 [AppDelegate] applicationDidFinishLaunching started")
        HotkeyManager.shared.registerHotkeys()
        print("⌨️  [AppDelegate] hotkeys registered")

        let agentService = AgentStatusService.shared
        print("📌 [AppDelegate] AgentStatusService acquired")
        let panelManager = StatusOverlayPanel.shared
        print("📌 [AppDelegate] StatusOverlayPanel acquired")
        
        print("🔧 [AppDelegate] initializing panel...")
        panelManager.initialize(with: agentService)
        print("✅ [AppDelegate] panel initialized")
        
        print("👀 [AppDelegate] showing panel...")
        panelManager.show()
        print("✅ [AppDelegate] panel shown")
        
        print("🔄 [AppDelegate] starting SimulationOrchestrator...")
        SimulationOrchestrator(agentService).start()
        print("✅ [AppDelegate] app startup complete\n")
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatusOverlayPanel.shared.hide()
        self.taskExecutor.resetProcessing()
    }
}
