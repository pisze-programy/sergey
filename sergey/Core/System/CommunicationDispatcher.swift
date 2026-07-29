import Foundation

final class CommunicationDispatcher {
    static let shared = CommunicationDispatcher()
    
    private let settings = SettingsStore.shared
    private let service = AgentStatusService.shared
    private let notifications = SystemNotificationService.shared
    
    private init() {}
    
    func dispatch(message: String, priority: NotificationPriority) {
        if settings.isFocusModeEnabled {
            if priority == .critical {
                notifications.sendNotification(
                    title: "Sergey - Critical",
                    body: message,
                    priority: .critical
                )
            }
        } else {
            notifications.sendNotification(
                title: "Sergey",
                body: message,
                priority: priority
            )
            service.updateStatusMessage(message)
        }
    }
    
    func updateStatusOnly(_ text: String) {
        if !settings.isFocusModeEnabled {
            service.updateStatusMessage(text)
        }
    }
}
