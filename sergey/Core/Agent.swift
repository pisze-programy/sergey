import Foundation
import CoreGraphics

final class Agent {
    private let screen = ScreenCapture()
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()
    
    private var lastCapturedImage: CGImage?
    private var currentLivePrompt: String = ""

    func captureScreenOnly() {
        print("📸 [Agent] Starting screen capture only...")
        Task {
            do {
                let image = try await screen.capturePrimaryDisplay()
                self.lastCapturedImage = image
                print("✅ [Agent] Screen captured successfully.")
                ResponseOverlayManager.shared.show(text: "Screen captured. Ready for voice prompt.", isLoading: false)
            } catch {
                print("❌ [Agent] Capture error: \(error)")
                ResponseOverlayManager.shared.show(text: "Capture error: \(error.localizedDescription)", isLoading: false)
            }
        }
    }

    func startListening() {
        print("🎙️ [Agent] Starting listening mode...")
        Task {
            speech.startLiveTranscription { [weak self] partialText in
                if let self = self {
                    self.currentLivePrompt = partialText
                    ResponseOverlayManager.shared.show(text: partialText.isEmpty ? "Listening..." : partialText, isLoading: true)
                }
            }

            do {
                print("📸 [Agent] Capturing screen for context...")
                let image = try await screen.capturePrimaryDisplay()
                self.lastCapturedImage = image
                print("✅ [Agent] Screen captured and stored.")
                if self.currentLivePrompt.isEmpty {
                    ResponseOverlayManager.shared.show(text: "Screen captured. Ready for voice prompt.", isLoading: false)
                }
            } catch {
                print("❌ [Agent] Capture error: \(error)")
                ResponseOverlayManager.shared.show(text: "Capture error: \(error.localizedDescription)", isLoading: false)
            }
        }
    }

    func stopAndProcess(audioURL: URL?) async {
        print("🛑 [Agent] Stopping listening and processing...")
        let liveText = speech.stopLiveTranscription()
        let prompt = !liveText.isEmpty ? liveText : (!currentLivePrompt.isEmpty ? currentLivePrompt : "What is on this screen?")
        currentLivePrompt = ""

        print("📝 [Agent] Final Prompt: \"\(prompt)\"")

        ResponseOverlayManager.shared.show(text: "Prompt: \"\(prompt)\"\nThinking...", isLoading: true)

        do {
            print("🤖 [Agent] Sending request to Ollama...")
            var imagesToSend: [Data] = []
            if let image = self.lastCapturedImage, let pngData = screen.imageToPNGData(image) {
                imagesToSend.append(pngData)
                print("🖼️ [Agent] Attached screenshot to Ollama request.")
            }

            let response = try await ollama.generateResponse(prompt: prompt, images: imagesToSend)
            print("✅ [Agent] Ollama responded successfully.")
            ResponseOverlayManager.shared.show(text: response, isLoading: false)

        } catch {
            print("❌ [Agent] Agent error: \(error)")
            let errorMsg = error.localizedDescription
            ResponseOverlayManager.shared.show(text: "Error: \(errorMsg)", isLoading: false)
        }
    }

    func processVoiceAndScreen(audioURL: URL?) async {
        print("🔄 [Agent] Process voice and screen triggered.")
        await stopAndProcess(audioURL: audioURL)
    }
}
