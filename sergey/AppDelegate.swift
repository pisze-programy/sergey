import AppKit
import Foundation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskDispatcher: TaskDispatcher?
    private var onboardingWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Kill old instances — keeps Xcode debugger session clean on re-launch.
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == Bundle.main.bundleIdentifier {
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        // Pre-check permissions for fast status on first access.
        PermissionManager.shared.refresh()

        HotkeyManager.shared.registerHotkeys()

        let agentService = AgentStatusService.shared
        let panelManager = StatusOverlayPanel.shared

        panelManager.initialize(with: agentService)
        panelManager.show()

        taskDispatcher = TaskDispatcher.shared
        taskDispatcher?.start()

        Task.detached {
            await ParakeetTranscriptionService.shared.preloadModel()
        }

        showOnboardingIfNeeded()
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {
        DictationOrchestrator.shared.forceCleanup()
        StatusOverlayPanel.shared.hide()
        taskDispatcher?.stop()
    }


    @MainActor private func showOnboardingIfNeeded() {
        guard !SettingsStore.shared.onboardingShown else { return }

        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Sergey"
        window.setContentSize(NSSize(width: 480, height: 580))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Mark onboarding complete on any close — the permission status in Settings
        // will remind the user if something is still missing.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            SettingsStore.shared.onboardingShown = true
            self?.onboardingWindow = nil
        }

        onboardingWindow = window
    }
}
