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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    func sendNotification(title: String, body: String, priority: NotificationPriority) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // In a real scenario, we could adjust the sound or interruption level based on priority
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
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
}
