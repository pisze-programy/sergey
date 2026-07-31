import AppKit
import Foundation

final class FrontmostAppTool: AgentTool {
    let name = "frontmost_app"
    let description = "Returns the name and bundle identifier of the frontmost (active) application."

    func execute(parameters: [String: Any]) async throws -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return "No frontmost application"
        }

        let appName = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier ?? "unknown"
        return "Frontmost app: \(appName) (\(bundleID))"
    }
}
