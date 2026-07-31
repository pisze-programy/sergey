import AppKit
import Foundation

final class OpenURLTool: AgentTool {
    let name = "open_url"
    let description = "Opens a URL in the default browser. Parameter: url (string, required)."

    func execute(parameters: [String: Any]) async throws -> String {
        guard let urlString = parameters["url"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            throw NSError(
                domain: "sergey.tools.open_url",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid or missing 'url' parameter"]
            )
        }

        // Only allow http/https. Other schemes (file:, javascript:, etc.) could
        // trigger unintended actions on the user's machine.
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw NSError(
                domain: "sergey.tools.open_url",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported URL scheme: \(url.scheme ?? "(none)") (only http/https allowed)"]
            )
        }

        guard NSWorkspace.shared.open(url) else {
            throw NSError(
                domain: "sergey.tools.open_url",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open URL: \(urlString)"]
            )
        }

        return "Opened \(urlString)"
    }
}
