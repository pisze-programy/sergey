import Foundation

final class PromptAssembler {
    static let shared = PromptAssembler()
    private init() {}

    func assembleAgentPrompt(userRequest: String, providedHistory: String?) -> String {
        let template = PromptManager.shared.loadPrompt(name: "AGENT_REACT_PROMPT")
        let inventory = SkillRegistry.shared.inventorySummary
        let sessionHistory = providedHistory ?? HistoryStore.shared.getSessionHistory()

        let assembledPrompt = template
            .replacingOccurrences(of: "{{inventory}}", with: inventory)
            .replacingOccurrences(of: "{{user_request}}", with: userRequest)
            .replacingOccurrences(of: "{{session_history}}", with: sessionHistory)

        return assembledPrompt
    }
    
    func assembleSystemPrompt() -> String {
        return PromptManager.shared.loadPrompt(name: "OLLAMA_SYSTEM_PROMPT")
    }
}
