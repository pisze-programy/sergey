import Foundation

final class HistoryManager {
    static let shared = HistoryManager()
    private init() {}

    func checkAndSummarizeIfNeeded(threshold: Int = 10, compressionLimit: Int = 5) async -> String? {
        guard let lastSession = HistoryStore.shared.data.sessions.last,
              lastSession.messages.count > threshold else {
            return nil
        }
        
        let indexToKeep = lastSession.messages.count - threshold
        let messagesToSummarize = lastSession.messages[..<indexToKeep]
        
        let textToSummarize = messagesToSummarize
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        
        let summaryPromptTemplate = PromptManager.shared.loadPrompt(name: "HISTORY_SUMMARIZATION_PROMPT")
        
        let summaryPrompt = summaryPromptTemplate
            .replacingOccurrences(of: "{{session_history}}", with: textToSummarize)

        let systemPrompt = PromptManager.shared.loadPrompt(name: "OLLAMA_SYSTEM_PROMPT")

        do {
            var summary = ""
            for try await chunk in OllamaClient().generateResponse(systemPrompt: systemPrompt, prompt: summaryPrompt, images: []) {
                summary += chunk
            }
            
            if !summary.isEmpty {
                let remainingMessages = lastSession.messages[indexToKeep...]
                let summaryMessage = HistoryMessage(role: "system", content: "Summary of previous conversation context")
                
                let allMessagesForPrompt = [summaryMessage] + Array(remainingMessages)
                let condensedHistory = allMessagesForPrompt
                    .map { "\($0.role.capitalized): \($0.content)" }
                    .joined(separator: "\n")
                
                return condensedHistory
            }
            return nil
        } catch {
            print("[HistoryManager] Error: \(error)")
            return nil
        }
    }
}
