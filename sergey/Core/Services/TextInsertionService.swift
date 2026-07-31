import AppKit
import CoreGraphics
import OSLog

struct TextInsertionService {
    private static let log = Logger(subsystem: "sergey", category: "TextInsertion")

    /// Inserts text into the frontmost app. Strategy chain:
    /// 1. Accessibility (AX) — exact, works in native apps.
    /// 2. Synthesized keyboard events (CGEvent) — works in browsers/web content
    ///    where AX `kAXSelectedTextAttribute` is not supported.
    /// 3. Clipboard — always filled as a last-resort fallback (manual Cmd+V).
    @discardableResult
    static func insertText(_ text: String, targetAppPID: pid_t? = nil) -> Bool {
        guard !text.isEmpty else { return false }

        // Clipboard is always populated so the user can paste manually if both
        // automated methods fail.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if insertViaAccessibility(text, targetAppPID: targetAppPID) {
            return true
        }

        if injectViaKeyboardEvents(text) {
            return true
        }

        log.error("AX and keyboard injection failed – text left in clipboard")
        return false
    }

    // MARK: - Accessibility insertion

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
              let focusedValue = focusedValue
        else { return false }

        // CF types bridge unconditionally; the value is guaranteed non-nil here.
        let focusedElement = focusedValue as! AXUIElement

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

    // MARK: - Keyboard event injection

    /// Types the text at the current cursor location by synthesizing keyboard
    /// events via `CGEventKeyboardSetUnicodeString`. Works in nearly every text
    /// field on macOS including browsers; some Electron apps and secure password
    /// fields can drop characters (platform constraint).
    private static func injectViaKeyboardEvents(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        let utf16 = Array(text.utf16)
        let chunkSize = 20 // per-event character limit of the API
        var index = 0

        while index < utf16.count {
            let end = min(index + chunkSize, utf16.count)
            let chunk = Array(utf16[index..<end])
            postChunk(chunk)
            index = end

            // Small pause between chunks: some apps (Electron) drop characters
            // when events arrive back-to-back.
            if index < utf16.count {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        return true
    }

    private static func postChunk(_ chunk: [UniChar]) {
        var chunk = chunk
        let length = chunk.count
        guard length > 0 else { return }

        let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        down?.keyboardSetUnicodeString(stringLength: length, unicodeString: &chunk)
        down?.post(tap: .cgSessionEventTap)

        let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        up?.keyboardSetUnicodeString(stringLength: length, unicodeString: &chunk)
        up?.post(tap: .cgSessionEventTap)
    }
}
