import Foundation

final class InsertTextTool: AgentTool {
    let name = "insert_text"
    let description = "Inserts text into the frontmost application as if typed. Parameter: text (string, required). Only usable when explicitly enabled in Settings."

    func execute(parameters: [String: Any]) async throws -> String {
        // Safety gate: typing into the user's apps is dangerous (it can corrupt
        // work, e.g. source code). Disabled by default — enable in Settings.
        guard SettingsStore.shared.allowTextInsertion else {
            throw NSError(
                domain: "sergey.tools.insert_text",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "insert_text is disabled — enable it in Settings → General → Allow text insertion"]
            )
        }

        guard let text = parameters["text"] as? String, !text.isEmpty else {
            throw NSError(
                domain: "sergey.tools.insert_text",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid or missing 'text' parameter"]
            )
        }

        let success = TextInsertionService.insertText(text, targetAppPID: nil)
        return success ? "Text inserted" : "Failed to insert text"
    }
}
