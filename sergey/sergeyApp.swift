import SwiftUI

@main
struct AIBuddyApp: App {
    
    init() {
        print("✅ [App] AIBuddyApp init started")
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        MenuBarExtra("Sergey", systemImage: "sparkles") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
