import AppKit
import CoreGraphics
import OSLog

struct TextInsertionService {
    private static let log = Logger(subsystem: "sergey", category: "TextInsertion")

    @discardableResult
    static func insertText(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if insertViaAccessibility(text) {
            return true
        }

        log.error("AX insert failed – text left in clipboard")
        return false
    }

    private static func insertViaAccessibility(_ text: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

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
