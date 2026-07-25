import SwiftUI

@main
struct AIBuddyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        MenuBarExtra("Sergey", systemImage: "sparkles") {
            MenuBar(
               onQuit: {
                   NSApplication.shared.terminate(nil)
               },
               onSettings: {}
           )
        }
    }
}
