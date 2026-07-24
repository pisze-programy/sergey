import Foundation
import CoreGraphics

final class Agent {
    private let screen = ScreenCapture()
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()
    
    private var lastCapturedImage: CGImage?
    private var currentLivePrompt: String = ""

    func captureScreenOnly() {
        Task {
            do {
                let image = try await screen.capturePrimaryDisplay()
                self.lastCapturedImage = image
                ResponseOverlayManager.shared.show(text: "Screen captured. Ready for voice prompt.", isLoading: false)
            } catch {
                ResponseOverlayManager.shared.show(text: "Capture error: \(error.localizedDescription)", isLoading: false)
            }
        }
    }

    func startListening() {
        Task {
            do {
                let image = try await screen.capturePrimaryDisplay()
                self.lastCapturedImage = image
                ResponseOverlayManager.shared.show(text: "Listening...", isLoading: true)

                speech.startLiveTranscription { [weak self] partialText in
                    self?.currentLivePrompt = partialText
                    ResponseOverlayManager.shared.show(text: partialText.isEmpty ? "Listening..." : partialText, isLoading: true)
                }
            } catch {
                ResponseOverlayManager.shared.show(text: "Capture error: \(error.localizedDescription)", isLoading: false)
            }
        }
    }

    func stopAndProcess(audioURL: URL?) async {
        let liveText = speech.stopLiveTranscription()
        let prompt = !liveText.isEmpty ? liveText : (!currentLivePrompt.isEmpty ? currentLivePrompt : "What is on this screen?")
        currentLivePrompt = ""

        print("🎙️ STT Final Prompt -> Ollama: \"\(prompt)\"")

        ResponseOverlayManager.shared.show(text: "Prompt: \"\(prompt)\"\nThinking...", isLoading: true)

        do {
            let image: CGImage
            if let captured = lastCapturedImage {
                image = captured
            } else {
                image = try await screen.capturePrimaryDisplay()
            }
            guard let pngData = screen.imageToPNGData(image) else {
                throw NSError(domain: "Agent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode screenshot"])
            }

            let response = try await ollama.generateResponse(prompt: prompt, images: [pngData])
            ResponseOverlayManager.shared.show(text: response, isLoading: false)

        } catch {
            ResponseOverlayManager.shared.show(text: "Error: \(error.localizedDescription)", isLoading: false)
        }
    }

    func processVoiceAndScreen(audioURL: URL?) async {
        await stopAndProcess(audioURL: audioURL)
    }
}
