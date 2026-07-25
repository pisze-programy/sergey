import Foundation
import CoreGraphics

final class Agent {
    private let screen = ScreenCapture()
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()

    private var lastCapturedImage: CGImage?
    private var currentLivePrompt: String = ""
    private var isProcessing = false

    func resetProcessing() {
        isProcessing = false
    }

    func captureScreenOnly() {
        guard !isProcessing else { return }
        print("[Agent] Starting screen capture only...")
        Task {
            do {
                let image = try await screen.capturePrimaryDisplay()
                self.lastCapturedImage = image
                print("[Agent] Screen captured successfully.")
                ResponseOverlayManager.shared.show(text: "Screen captured. Ready for voice prompt.", isLoading: false)
            } catch {
                print("[Agent] Capture error: \(error)")
                ResponseOverlayManager.shared.show(text: "Capture error: \(error.localizedDescription)", isLoading: false)
            }
        }
    }

    func startListening() {
        guard !isProcessing else { 
            print("[Agent] Busy processing another request. Ignoring.")
            return 
        }
        
        print("[Agent] Starting listening mode...")
        Task {
            speech.startLiveTranscription { [weak self] partialText in
                if let self = self {
                    self.currentLivePrompt = partialText
                    ResponseOverlayManager.shared.show(text: partialText.isEmpty ? "Listening..." : partialText, isLoading: true)
                }
            }

            // No automatic capture here. We rely on lastCapturedImage if it exists from captureScreenOnly()
            if self.currentLivePrompt.isEmpty {
                ResponseOverlayManager.shared.show(text: ResponseOverlayManager.shared.getRandomPlaceholder(), isLoading: false)
            }
        }
    }

    func executeRequest(audioURL: URL?) async {
        guard !isProcessing else { return }
        isProcessing = true
        
        defer { isProcessing = false }
        
        print("[Agent] Stopping listening and processing...")
        let liveText = speech.stopLiveTranscription()
        let prompt = !liveText.isEmpty ? liveText : (!currentLivePrompt.isEmpty ? currentLivePrompt : "Analyze this screen and provide helpful context or answers about its content.")
        currentLivePrompt = ""

        print("[Agent] Final Prompt: \"\(prompt)\"")
        HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: prompt))
        ResponseOverlayManager.shared.show(text: "Prompt: \"\(prompt)\"\nThinking...", isLoading: true)

        do {
            print("[Agent] Sending request to Ollama...")
            var imagesToSend: [Data] = []
            if let image = self.lastCapturedImage, let pngData = screen.imageToPNGData(image) {
                imagesToSend.append(pngData)
                print("[Agent] Attached screenshot to Ollama request.")
            } else {
                print("[Agent] No active screenshot found. Sending text-only request.")
            }

            var fullResponse = ""
            for try await chunk in ollama.generateResponse(prompt: prompt, images: imagesToSend) {
                print("[Ollama Chunk] \(chunk)")
                fullResponse += chunk
                ResponseOverlayManager.shared.show(text: fullResponse, isLoading: true)
            }

            print("[Agent] Ollama finished streaming. Final Response: \(fullResponse)")
            ResponseOverlayManager.shared.show(text: fullResponse, isLoading: false)
            HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: fullResponse))

        } catch {
            print("[Agent] Agent error: \(error)")
            let errorMsg = error.localizedDescription
            ResponseOverlayManager.shared.show(text: "Error: \(errorMsg)", isLoading: false)
        }
    }
}
