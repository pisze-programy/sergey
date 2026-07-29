import Foundation

final class TaskExecutor {
    private let ollama = OllamaClient()
    private let service = AgentStatusService.shared

    private var isProcessing = false

    func resetProcessing() {
        isProcessing = false
    }

    func executeRequest() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        // TODO: Integration
        do { isProcessing = false }
    }
}
