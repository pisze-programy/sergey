import AppKit
import AVFoundation
import Combine
import UserNotifications

enum PermissionType: String, CaseIterable, Identifiable {
    case microphone
    case accessibility
    case notifications

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .microphone:    return "mic.fill"
        case .accessibility: return "hand.raised.fill"
        case .notifications: return "bell.badge.fill"
        }
    }

    var title: String {
        switch self {
        case .microphone:    return "Microphone"
        case .accessibility: return "Accessibility"
        case .notifications: return "Notifications"
        }
    }

    var description: String {
        switch self {
        case .microphone:
            return "Sergey needs access to the microphone to record your voice prompts."
        case .accessibility:
            return "Sergey uses Accessibility APIs to insert transcribed text directly into other applications."
        case .notifications:
            return "Sergey sends notifications when background tasks complete or require attention."
        }
    }

    var isRequired: Bool {
        switch self {
        case .microphone, .accessibility: return true
        case .notifications:             return false
        }
    }

    var settingsURL: String {
        switch self {
        case .microphone:    return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .notifications: return "x-apple.systempreferences:com.apple.preference.notifications"
        }
    }
}

enum PermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined
    case restricted

    var isGranted: Bool { self == .granted }

    var label: String {
        switch self {
        case .granted:      return "Granted"
        case .denied:       return "Denied"
        case .notDetermined:return "Not Set"
        case .restricted:   return "Restricted"
        }
    }
}

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    @Published var notificationStatus: PermissionStatus = .notDetermined

    private init() {
        microphoneStatus = readMicrophoneStatus()
        accessibilityStatus = readAccessibilityStatus()
    }

    var allRequiredGranted: Bool {
        microphoneStatus.isGranted && accessibilityStatus.isGranted
    }

    func refresh() {
        microphoneStatus = readMicrophoneStatus()
        accessibilityStatus = readAccessibilityStatus()
        refreshNotificationStatus()
    }

    func openSettings(for type: PermissionType) {
        guard let url = URL(string: type.settingsURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func readMicrophoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:       return .granted
        case .denied:           return .denied
        case .notDetermined:    return .notDetermined
        case .restricted:       return .restricted
        @unknown default:       return .notDetermined
        }
    }

    private func readAccessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    private func refreshNotificationStatus() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = self?.statusFromUNAuthorization(settings.authorizationStatus) ?? .notDetermined
            }
        }
    }

    private func statusFromUNAuthorization(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}
