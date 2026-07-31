import Foundation

/// Drives a real Chrome/Chromium browser through the Chrome DevTools Protocol
/// (CDP). Stage 1 supports the `navigate`, `read`, `title`, `screenshot` and
/// `elements` actions.
///
/// The tool relies on the shared `BrowserSession` (owns/attaches to Chrome) and
/// the shared `CDPClient` (WebSocket JSON-RPC). The CDP socket is intentionally
/// left open between calls — both are singletons and the browser is cleaned up
/// at app quit — so a task that navigates then reads makes one connection.
final class BrowserTool: AgentTool {
    let name = "browser"
    let description = "Controls a real Chrome browser via DevTools. Action: navigate (url required) — opens a page and waits for it to load; read — returns the visible text of the current page (capped at 8000 chars); title — returns the page title; screenshot — captures the current page as a JPEG, saves it to a temp file and returns its path; elements — returns the page's DOM structure: interactive elements (links, buttons, inputs, headings) with text, href and placeholder, deduplicated; cheaper than a screenshot for locating content. Parameter: action (string, required), url (string, required for navigate)."

    private static let errorDomain = "sergey.tools.browser"

    /// Overall budget for the page to reach `document.readyState == "complete"`
    /// AND for the document URL to match the navigation target.
    private static let pageLoadTimeout: TimeInterval = 15
    /// Poll interval while waiting for the page to finish loading.
    private static let pageLoadPollInterval: TimeInterval = 0.5
    /// Per-command timeout while polling; a slow evaluate must not abort the loop.
    private static let pageLoadCommandTimeout: TimeInterval = 5
    /// Maximum number of characters returned by the `read` action.
    private static let maxReadLength = 8000

    func execute(parameters: [String: Any]) async throws -> String {
        // Safety gate: driving a real browser can surprise the user (windows,
        // history, network traffic). Disabled by default — enable in Settings.
        guard SettingsStore.shared.allowBrowser else {
            throw NSError(
                domain: Self.errorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Browser automation is disabled. Enable it in Settings → General → Agent Tools."]
            )
        }

        // All parameter values arrive as Strings (ActionInterpreter strips
        // quotes); "focus" is injected by the executor — ignore it.
        let action = parameters["action"] as? String ?? ""

        // Validate the action up front so an unknown action never starts (and
        // potentially hides) a Chrome window.
        guard ["navigate", "read", "title", "screenshot", "elements"].contains(action) else {
            throw NSError(
                domain: Self.errorDomain,
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unknown browser action '\(action)' (supported: navigate, read, title, screenshot, elements)"]
            )
        }

        // Validate the url up front so we never start the browser for a
        // malformed request.
        var urlString: String?
        if action == "navigate" {
            guard let raw = parameters["url"] as? String, !raw.isEmpty else {
                throw NSError(
                    domain: Self.errorDomain,
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing or empty 'url' parameter (required for browser navigate)"]
                )
            }
            guard raw.hasPrefix("http://") || raw.hasPrefix("https://") else {
                throw NSError(
                    domain: Self.errorDomain,
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid 'url' for browser navigate: '\(raw)' (must start with http:// or https://)"]
                )
            }
            urlString = raw
        }

        try await BrowserSession.shared.ensureRunning()

        let wsURL = try await CDPClient.shared.discoverPageWebSocketURL(endpoint: BrowserSession.shared.cdpEndpointURL())
        try await CDPClient.shared.connect(to: wsURL)

        switch action {
        case "navigate":
            let target = urlString ?? ""
            // Navigation errors (e.g. CDP Page.navigate reporting an errorText)
            // are propagated so the observation reports an honest failure.
            try await CDPClient.shared.navigate(to: target)
            let urlPrefix = navigationPrefix(for: target)
            if await waitForDocument(urlPrefix: urlPrefix) {
                let title = try await CDPClient.shared.pageTitle()
                return "Navigated to \(target). Page title: \(title)"
            }
            // The new document never matched the target — either it is still
            // loading or it was redirected. Never claim success against the
            // previous document. (On a dead CDP socket this evaluate throws a
            // clear error instead.)
            let actualURL = try await currentDocumentURL()
            return "Navigated to \(target). Current document URL: \(actualURL). The page may still be loading or was redirected."

        case "read":
            let text = try await CDPClient.shared.currentPageText()
            guard !text.isEmpty else {
                return "Page has no readable text"
            }
            if text.count > Self.maxReadLength {
                return String(text.prefix(Self.maxReadLength)) + "\n…[truncated]"
            }
            return text

        case "title":
            return try await CDPClient.shared.pageTitle()

        case "screenshot":
            let data = try await CDPClient.shared.screenshotJPEG(quality: 75)
            let path = FileManager.default.temporaryDirectory
                .appendingPathComponent("sergey-browser-\(UUID().uuidString).jpg")
            do {
                try data.write(to: path)
            } catch {
                throw NSError(
                    domain: Self.errorDomain,
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to write browser screenshot to \(path.path): \(error.localizedDescription)"]
                )
            }
            return "Saved browser screenshot to \(path.path). It shows the agent's browser page (viewport), not the user's screen."

        case "elements":
            let rows = try await CDPClient.shared.pageElements()
            guard !rows.isEmpty else {
                return "No interactive elements found on this page (page may not have loaded, or it is a minimal/blank page)."
            }
            var lines: [String] = []
            for (index, row) in rows.enumerated() where row.count >= 5 {
                let tag = row[0]
                let text = row[1]
                let href = row[2]
                let placeholder = row[3]
                var line = "\(index + 1). [\(tag)] \(text.isEmpty ? "(no text)" : text)"
                if !href.isEmpty { line += " → \(href)" }
                if !placeholder.isEmpty { line += " (placeholder: \(placeholder))" }
                lines.append(line)
            }
            var result = lines.joined(separator: "\n")
            if result.count > 2500 {
                result = String(result.prefix(2500)) + "\n…[truncated]"
            }
            return result

        default:
            // Unreachable: the action was validated before the browser launched.
            throw NSError(
                domain: Self.errorDomain,
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unknown browser action '\(action)' (supported: navigate, read, title, screenshot, elements)"]
            )
        }
    }

    /// Polls until the NEW document after a navigation is fully loaded:
    /// `document.readyState == "complete"` AND `document.URL` begins with the
    /// target's `scheme://host[/path]` prefix (every 0.5s, up to 15s). The URL
    /// check guards against the classic false positive where the first poll
    /// still sees the PREVIOUS document's "complete" readyState.
    ///
    /// Returns false on timeout rather than throwing — a slow page should not
    /// fail the whole action; the caller then reports the actual document URL
    /// honestly. Returns false immediately when the CDP socket is gone (code 30
    /// / 41) so the caller's next command fails fast with a clear error instead
    /// of burning the remaining timeout. Transient CDP errors while the page is
    /// settling (e.g. the previous context was destroyed mid-navigation) are
    /// tolerated and polling continues.
    private func waitForDocument(urlPrefix: String) async -> Bool {
        let deadline = Date().addingTimeInterval(Self.pageLoadTimeout)
        while Date() < deadline {
            do {
                let result = try await CDPClient.shared.sendCommand(
                    "Runtime.evaluate",
                    // One round-trip per poll: readyState and URL joined by a
                    // control character that can never appear in a URL.
                    params: [
                        "expression": "document.readyState + '\\u0001' + document.URL",
                        "returnByValue": true
                    ],
                    timeout: Self.pageLoadCommandTimeout
                )
                if let payload = result["result"] as? [String: Any],
                   let combined = payload["value"] as? String {
                    let parts = combined.split(
                        separator: "\u{0001}",
                        maxSplits: 1,
                        omittingEmptySubsequences: false
                    )
                    if parts.count == 2 {
                        let state = String(parts[0])
                        let currentURL = String(parts[1])
                        if state == "complete", currentURL.hasPrefix(urlPrefix) {
                            return true
                        }
                    }
                }
            } catch {
                // A dead socket can never recover within this loop — bail so
                // the caller's next command surfaces a clear error instead of
                // waiting out the timeout.
                if Self.isTerminalCDPError(error) {
                    return false
                }
                // Tolerate transient errors and keep polling.
            }
            do {
                try await Task.sleep(for: .seconds(Self.pageLoadPollInterval))
            } catch {
                // Sleep failed (e.g. the enclosing task was cancelled) — stop
                // polling; the caller's next command reports the real error.
                return false
            }
        }
        return false
    }

    /// Reads the current `document.URL` via Runtime.evaluate. Returns
    /// "(unknown)" if the evaluate response lacks a value.
    private func currentDocumentURL() async throws -> String {
        let result = try await CDPClient.shared.sendCommand(
            "Runtime.evaluate",
            params: ["expression": "document.URL", "returnByValue": true],
            timeout: Self.pageLoadCommandTimeout
        )
        if let payload = result["result"] as? [String: Any],
           let url = payload["value"] as? String {
            return url
        }
        return "(unknown)"
    }

    /// True when `error` means the CDP socket is gone for good — not connected
    /// (code 30) or connection closed (code 41) in CDPClient's error domain.
    /// Continuing to poll would just burn the remaining timeout on a dead
    /// connection.
    private static func isTerminalCDPError(_ error: Error) -> Bool {
        // Every Error bridges to NSError, so a plain cast is sufficient.
        let nsError = error as NSError
        return nsError.domain == "sergey.tools.browser.cdp" && (nsError.code == 30 || nsError.code == 41)
    }

    /// Builds the prefix the live document URL must match after navigating to
    /// `target`: `scheme://host` (host lowercased, port preserved) plus the
    /// path when the target has one. `document.URL.hasPrefix(prefix)` then
    /// tolerates a trailing "/" and an uppercase host in the actual URL.
    private func navigationPrefix(for target: String) -> String {
        if let url = URL(string: target), let scheme = url.scheme, let host = url.host {
            var prefix = scheme.lowercased() + "://" + host.lowercased()
            if let port = url.port {
                prefix += ":\(port)"
            }
            if url.path.isEmpty == false && url.path != "/" {
                prefix += url.path
            }
            while prefix.hasSuffix("/") {
                prefix.removeLast()
            }
            return prefix
        }
        // Defensive fallback (unreachable: target is pre-validated to start
        // with http:// or https://): just trim the trailing slash.
        var prefix = target
        while prefix.hasSuffix("/") {
            prefix.removeLast()
        }
        return prefix
    }
}
