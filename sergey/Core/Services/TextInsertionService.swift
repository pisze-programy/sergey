import AppKit
import CoreGraphics
import OSLog

struct TextInsertionService {
    private static let log = Logger(subsystem: "sergey", category: "TextInsertion")

    @discardableResult
    static func insertText(_ text: String, targetAppPID: pid_t? = nil) -> Bool {
        guard !text.isEmpty else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if insertViaAccessibility(text, targetAppPID: targetAppPID) {
            return true
        }

        log.error("AX insert failed – text left in clipboard")
        return false
    }

    private static func insertViaAccessibility(_ text: String, targetAppPID: pid_t?) -> Bool {
        let pid: pid_t
        if let targetAppPID = targetAppPID {
            pid = targetAppPID
        } else {
            guard let app = NSWorkspace.shared.frontmostApplication else { return false }
            pid = app.processIdentifier
        }

        let appElement = AXUIElementCreateApplication(pid)

        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedElement = focusedValue as! AXUIElement?
        else { return false }

        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String ?? ""
        let textRoles: Set<String> = [
            kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField"
        ]

        var selectedRange: CFTypeRef?
        let hasSelection = AXUIElementCopyAttributeValue(
            focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success

        guard textRoles.contains(role) || hasSelection else { return false }

        let selResult = AXUIElementSetAttributeValue(
            focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)

        return selResult == .success
    }
}
