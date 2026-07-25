import Foundation
import CoreGraphics

final class Agent {
    private let screen = ScreenCapture()
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()

    private var lastCapturedImage: CGImage?
    private var currentLivePrompt: String = ""

    func captureScreenOnly() {
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
        print("[Agent] Starting listening mode...")
        Task {
            speech.startLiveTranscription { [weak self] partialText in
                if let self = self {
                    self.currentLivePrompt = partialText
                    ResponseOverlayManager.shared.show(text: partialText.isEmpty ? "Listening..." : partialText, isLoading: true)
                }
            }

            if self.currentLivePrompt.isEmpty {
                ResponseOverlayManager.shared.show(text: "Ready for voice prompt.", isLoading: false)
            }
        }
    }

    func processVoiceAndScreen(audioURL: URL?) async {
        print("[Agent] Stopping listening and processing...")
        // Clear last captured image so we don't send stale screenshots in the STT flow
        self.lastCapturedImage = nil

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
