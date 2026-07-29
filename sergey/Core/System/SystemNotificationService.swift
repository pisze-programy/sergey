import Foundation
import UserNotifications

enum NotificationPriority {
    case critical
    case normal
    case low
}

final class SystemNotificationService {
    static let shared = SystemNotificationService()
    
    private init() {
        requestPermission()
    }
    
    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }
    
    func sendNotification(title: String, body: String, priority: NotificationPriority) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if priority == .critical {
            content.interruptionLevel = .critical
        } else if priority == .normal {
            content.interruptionLevel = .timeSensitive
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
