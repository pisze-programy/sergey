import Foundation
import UserNotifications

enum NotificationPriority {
    case critical
    case warning
    case normal
    case info
    case low
}

final class SystemNotificationService {
    static let shared = SystemNotificationService()
    
    private var permissionRequested = false
    
    private init() {}
    
    private func ensurePermission() {
        guard !permissionRequested else { return }
        permissionRequested = true
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func sendNotification(title: String, body: String, priority: NotificationPriority) {
        ensurePermission()
        guard Bundle.main.bundleIdentifier != nil else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if priority == .critical {
            content.interruptionLevel = .critical
        } else if priority == .warning {
            content.interruptionLevel = .timeSensitive
        } else if priority == .normal {
            content.interruptionLevel = .active
        } else if priority == .info {
            content.interruptionLevel = .passive
        } else {
            content.interruptionLevel = .passive
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
