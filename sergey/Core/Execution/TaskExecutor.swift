import Foundation
import CoreGraphics
import AppKit
import Combine

final class Agent {
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()
    private var cancellables = Set<AnyCancellable>()

    private var currentLivePrompt: String = ""
    private var isProcessing = false

    init() {
        setupObservers()
    }

    private func setupObservers() {
        SettingsStore.shared.$sttEngineType
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                print("[Agent] Engine type changed, updating engine...")
                self?.speech.updateEngine()
            }
            .store(in: &cancellables)

        SettingsStore.shared.$speechLanguage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                print("[Agent] Language changed, updating engine...")
                self?.speech.updateEngine()
            }
            .store(in: &cancellables)
    }

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
        
        var capturedImages: [Data] = []
        do {
            let captureExecutor = ScreenCaptureExecutor()
            if let result = try await captureExecutor.execute(params: ["mode": "primary"]) as? SkillResult, 
               result.success, 
               let imageData = result.data as? Data {
                capturedImages.append(imageData)
                print("[Agent] Captured screenshot successfully")
            }
        } catch {
            print("[Agent] Failed to capture screenshot: \(error)")
        }

        let systemPrompt = PromptAssembler.shared.assembleSystemPrompt()
        let agent_prompt = PromptAssembler.shared.assembleAgentPrompt(userRequest: STT_final, providedHistory: condensedHistory)
        
        HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: STT_final))
        ResponseOverlayManager.shared.show(text: MessagingManager.shared.thinkingPrompt, isLoading: true)
        
        do {
            var fullResponse = ""
            let response = try await LLMService.shared.generateScopedResponse(
                systemPrompt: systemPrompt,
                prompt: agent_prompt,
                images: capturedImages,
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

            let cleanedText = ActionInterpreter.shared.cleanTextForDisplay(response.fullText)
            
            if let action = actionPart {
                HistoryStore.shared.appendMessage(HistoryMessage(role: "system", content: action))
                await handleActionIfPresent(response: cleanedText)
            } else {
                HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: response.fullText))
                ResponseOverlayManager.shared.show(text: cleanedText, isLoading: false)
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
