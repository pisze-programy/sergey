import Foundation

final class InsertTextTool: AgentTool {
    let name = "insert_text"
    let description = "Inserts text into the frontmost application as if typed. Parameter: text (string, required)."

    func execute(parameters: [String: Any]) async throws -> String {
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
