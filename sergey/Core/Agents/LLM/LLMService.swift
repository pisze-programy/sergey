import Foundation

struct LLMResponse {
    let fullText: String
    let thought: String?
    let action: String?
}

typealias LLMStreamHandler = (String) -> Void

final class LLMService {
    static let shared = LLMService()
    private let client = OllamaClient()
    private init() {}
    
    func generateScopedResponse(
        systemPrompt: String,
        prompt: String,
        images: [Data] = [],
        onChunk: LLMStreamHandler? = nil
    ) async throws -> LLMResponse {
        var fullText = ""
        
        do {
            for try await chunk in client.generateResponse(systemPrompt: systemPrompt, prompt: prompt, images: images) {
                fullText += chunk
                onChunk?(chunk)
            }
            
            return parseResponse(fullText)
        } catch {
            print("[LLMService] Error generating response: \(error)")
            throw error
        }
    }

    private func parseResponse(_ text: String) -> LLMResponse {
        var thought: String? = nil
        var action: String? = nil
        
        if let thoughtRange = text.range(of: "Thought:", options: .caseInsensitive), 
           let actionRange = text.range(of: "Action:", options: .caseInsensitive) {
            // Extract Thought (between 'Thought:' and 'Action:')
            let thoughtPart = text[thoughtRange.upperBound..<actionRange.lowerBound]
            thought = String(thoughtPart).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract Action (after 'Action:')
            let actionPart = text[actionRange.upperBound...]
            action = String(actionPart).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return LLMResponse(fullText: text, thought: thought, action: action)
    }
}
