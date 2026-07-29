import Foundation

final class CommunicationDispatcher {
    static let shared = CommunicationDispatcher()
    
    private let settings = SettingsStore.shared
    private let overlay = StatusOverlayManager.shared
    private let notifications = SystemNotificationService.shared
    
    private init() {}
    
    func dispatch(message: String, priority: NotificationPriority) {
        if settings.isFocusModeEnabled {
            // Focus Mode ON: Only critical notifications, NO overlay updates
            if priority == .critical {
                notifications.sendNotification(
                    title: "Sergey - Critical",
                    body: message,
                    priority: .critical
                )
            }
        } else {
            // Focus Mode OFF: All notifications + update overlay
            notifications.sendNotification(
                title: "Sergey",
                body: message,
                priority: priority
            )
            overlay.updateStatus(message)
        }
    }
    
    /// Use this for purely UI status updates that shouldn't trigger system notifications
    func updateStatusOnly(_ text: String) {
        if !settings.isFocusModeEnabled {
            overlay.updateStatus(text)
        }
    }
}
