import Foundation

/// Structured response from the LLM service.
struct LLMResponse {
    let fullText: String
    let thought: String?
    let action: String?
}

/// A typealias for a closure that handles real-time text streaming to the UI.
typealias LLMStreamHandler = (String) -> Void

final class LLMService {
    static let shared = LLMService()
    private let client = OllamaClient()
    private init() {}

    /// Generates a response from the LLM, parses structural components, and streams text.
    /// - Parameters:
    ///   - systemPrompt: The system instructions.
    ///   - prompt: The user prompt.
    ///   - images: Optional image data.
    ///   - onChunk: Closure called for every chunk of text to update UI.
    /// - Returns: A structured `LLMResponse` containing the full text, thought, and action parts.
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

    /// Parses the raw LLM text to extract 'Thought:' and 'ACTION:' components.
    private func parseResponse(_ text: String) -> LLMResponse {
        var thought: String? = nil
        var action: String? = nil
        
        if let thoughtRange = text.range(of: "Thought:"), 
           let actionRange = text.range(of: "ACTION:") {
            // Extract Thought (between 'Thought:' and 'ACTION:')
            let thoughtPart = text[thoughtRange.upperBound..<actionRange.lowerBound]
            thought = String(thoughtPart).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract Action (after 'ACTION:')
            let actionPart = text[actionRange.upperBound...]
            action = String(actionPart).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let actionRange = text.range(of: "ACTION:") {
            // Only Action found
            let actionPart = text[actionRange.upperBound...]
            action = String(actionPart).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let thoughtRange = text.range(of: "Thought:") {
            // Only Thought found
            let thoughtPart = text[thoughtRange.upperBound...]
            thought = String(thoughtPart).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return LLMResponse(fullText: text, thought: thought, action: action)
    }
}
