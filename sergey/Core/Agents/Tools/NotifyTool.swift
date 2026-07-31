import Foundation

final class NotifyTool: AgentTool {
    let name = "notify"
    let description = "Shows a macOS notification. Parameters: title (string, required), body (string, optional)."

    func execute(parameters: [String: Any]) async throws -> String {
        guard let title = parameters["title"] as? String, !title.isEmpty else {
            throw NSError(
                domain: "sergey.tools.notify",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid or missing 'title' parameter"]
            )
        }

        let body = (parameters["body"] as? String) ?? ""
        SystemNotificationService.shared.sendNotification(title: title, body: body, priority: .normal)
        return "Notification sent"
    }
}
