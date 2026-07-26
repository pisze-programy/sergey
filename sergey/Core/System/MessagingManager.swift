import Foundation

final class MessagingManager {
    static let shared = MessagingManager()
    private init() {}

    private let idlePrompts = [
        "How can I help?", "What is your command?", "How may I assist you?", "Anything else I can do?",
        "What needs analyzing?", "Ready for a task?", "Shall we start?", "What would you like to know?",
        "Is there something on your screen?", "What is your next request?"
    ]

    func getRandomIdlePrompt() -> String {
        return idlePrompts.randomElement()!
    }

    var listeningPrompt: String {
        return "Listening..."
    }

    var thinkingPrompt: String {
        return "Thinking..."
    }

    var genericErrorMessage: String {
        return "Something went wrong..."
    }
}
