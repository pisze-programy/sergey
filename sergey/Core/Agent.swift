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

        let condensedHistory = await HistoryManager.shared.checkAndSummarizeIfNeeded()
        
        let STT_final = speech.stopLiveTranscription()
        
        let systemPrompt = PromptAssembler.shared.assembleSystemPrompt()
        let agent_prompt = PromptAssembler.shared.assembleAgentPrompt(userRequest: STT_final, providedHistory: condensedHistory)
        
        HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: STT_final))
        ResponseOverlayManager.shared.show(text: MessagingManager.shared.thinkingPrompt, isLoading: true)
        
        do {
            var fullResponse = ""
            let response = try await LLMService.shared.generateScopedResponse(
                systemPrompt: systemPrompt,
                prompt: agent_prompt,
                onChunk: { chunk in
                    fullResponse += chunk
                    ResponseOverlayManager.shared.show(text: fullResponse, isLoading: true)
                }
            )

            let thoughtPart = response.thought
            let actionPart = response.action

            if let thought = thoughtPart {
                if !thought.isEmpty {
                   ResponseOverlayManager.shared.show(text: thought, isLoading: true)
                   HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: thought))
                } else {
                   ResponseOverlayManager.shared.show(text: MessagingManager.shared.thinkingPrompt, isLoading: true)
                }
            }

            if let action = actionPart {
                HistoryStore.shared.appendMessage(HistoryMessage(role: "system", content: action))
                await handleActionIfPresent(response: response.fullText)
            } else {
                // No action found in structural parsing, treat as standard assistant message
                // Note: we use the fullResponse captured during streaming to ensure consistency
                HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: response.fullText))
                ResponseOverlayManager.shared.show(text: response.fullText, isLoading: false)
            }

            print("[Agent] Processed successfully: \(response.fullText)")
        } catch {
            print("[Agent] Agent error: \(error)")
            ResponseOverlayManager.shared.show(text: MessagingManager.shared.genericErrorMessage, isLoading: false)
        }
    }

    private func handleActionIfPresent(response: String) async {
        //
    }
}
