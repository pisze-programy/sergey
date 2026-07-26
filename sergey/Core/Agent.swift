import Foundation
import CoreGraphics
import AppKit

final class Agent {
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()

    private var currentLivePrompt: String = ""
    private var isProcessing = false

    func resetProcessing() {
        isProcessing = false
    }

    func startListening() {
        guard !isProcessing else {
            print("[Agent] Busy processing another request. Ignoring.")
            return
        }
        
        Task {
            speech.startLiveTranscription { [weak self] partialText in
                if let self = self {
                    self.currentLivePrompt = partialText
                    ResponseOverlayManager.shared.show(text: partialText.isEmpty ? MessagingManager.shared.listeningPrompt : partialText, isLoading: true)
                }
            }

            if self.currentLivePrompt.isEmpty {
                let randomPrompt = MessagingManager.shared.getRandomIdlePrompt()
                ResponseOverlayManager.shared.show(text: randomPrompt, isLoading: false)
            }
        }
    }

    func executeRequest() async {
        guard !isProcessing else { return }
        isProcessing = true
        
        defer { isProcessing = false }
        
        var STT_final = speech.stopLiveTranscription()
        
        if let template = loadPrompt(name: "AGENT_REACT_PROMPT") {
            let inventory = SkillRegistry.shared.inventorySummary
            STT_final = template
                .replacingOccurrences(of: "{{inventory}}", with: inventory)
                .replacingOccurrences(of: "{{user_request}}", with: STT_final)
        }

        print("[Agent] Augmented Prompt: \(STT_final)")
        HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: STT_final))
        ResponseOverlayManager.shared.show(text: MessagingManager.shared.thinkingPrompt, isLoading: true)
        
        let systemPrompt = loadPrompt(name: "OLLAMA_SYSTEM_PROMPT")!

        do {
            var fullResponse = ""
            for try await chunk in ollama.generateResponse(systemPrompt: systemPrompt, prompt: STT_final, images: []) {
                fullResponse += chunk
                ResponseOverlayManager.shared.show(text: fullResponse, isLoading: true)
            }

            await handleActionIfPresent(response: fullResponse)
            
            ResponseOverlayManager.shared.show(text: fullResponse, isLoading: false)
            HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: fullResponse))
            print("[Agent] Ollama Response: \(fullResponse)")

        } catch {
            print("[Agent] Agent error: \(error)")
            ResponseOverlayManager.shared.show(text: MessagingManager.shared.genericErrorMessage, isLoading: false)
        }
    }

    private func loadPrompt(name: String) -> String? {
        let url = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Prompts")
        return try? String(contentsOf: url!, encoding: .utf8)
    }

    private func handleActionIfPresent(response: String) async {
        guard let actionRange = response.range(of: "ACTION:") else { return }
        let instructionPart = response[actionRange.upperBound...]
        
        guard let openParenIdx = instructionPart.firstIndex(of: "("),
              let closePorganIdx = instructionPart.firstIndex(of: ")"),
              openParenIdx < closePorganIdx else { return }

        let skillIdentifier = String(instructionPart[..<openParenIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let paramsString = String(instructionPart[instructionPart.index(after: openParenIdx)..<closePorganIdx])
        
        let parameters = parseParameters(paramsString)
        
        if let skill = SkillRegistry.shared.getSkill(name: skillIdentifier) {
            do {
                let result = try await skill.execute(parameters: parameters)
                HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: "Observation: \(result)"))
            } catch {
                HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: "Observation Error: \(error)"))
            }
        }
    }

    private func parseParameters(_ paramsString: String) -> [String: Any] {
        var dict: [String: Any] = [:]
        let pairs = paramsString.components(separatedBy: ",")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                let key = kv[0].trimmingCharacters(in: .whitespaces)
                var val = kv[1].trimmingCharacters(in: .whitespaces)
                if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                    val = String(val.dropFirst().dropLast())
                }
                dict[key] = val
            }
        }
        return dict
    }
}
