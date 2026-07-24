import Foundation
import CoreGraphics

final class Agent {
    private let screen = ScreenCapture()
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()
    
    private var lastCapturedImage: CGImage?

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
    
    func processVoiceAndScreen(audioURL: URL?) async {
        ResponseOverlayManager.shared.show(text: "Processing voice & screen...", isLoading: true)
        
        do {
            // 1. Capture screen if not already captured
            let image: CGImage
            if let captured = lastCapturedImage {
                image = captured
            } else {
                image = try await screen.capturePrimaryDisplay()
            }
            guard let pngData = screen.imageToPNGData(image) else {
                throw NSError(domain: "Agent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode screenshot"])
            }
            
            // 2. Transcribe voice if audioURL available
            var prompt = "What is on this screen?"
            if let url = audioURL {
                let transcribed = try await speech.transcribe(audioURL: url)
                if !transcribed.isEmpty {
                    prompt = transcribed
                }
            }
            
            ResponseOverlayManager.shared.show(text: "Prompt: \"\(prompt)\"\nThinking...", isLoading: true)
            
            // 3. Send to Ollama
            let response = try await ollama.generateResponse(prompt: prompt, images: [pngData])
            ResponseOverlayManager.shared.show(text: response, isLoading: false)
            
        } catch {
            ResponseOverlayManager.shared.show(text: "Error: \(error.localizedDescription)", isLoading: false)
        }
    }
}
