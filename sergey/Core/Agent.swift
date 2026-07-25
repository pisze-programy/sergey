import Foundation
import CoreGraphics
import AppKit

final class Agent {
    private let speech = SpeechRecognizer()
    private let ollama = OllamaClient()

    private var lastCapturedImage: CGImage?
    private var currentLivePrompt: String = ""
    private var isProcessing = false

    private let placeholders = [
        "How can I help?", "What is your command?", "How may I assist you?", "Anything else I can do?", 
        "What needs analyzing?", "Ready for a task?", "Shall we start?", "What would you like to know?", 
        "Is there something on your screen?", "What is your next request?"
    ]

    func resetProcessing() {
        isProcessing = false
    }

    func captureScreenOnly() {
        guard !isProcessing else { return }
        ResponseOverlayManager.shared.show(text: "Feature migration to Skills in progress...", isLoading: false)
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
                    ResponseOverlayManager.shared.show(text: partialText.isEmpty ? "Listening..." : partialText, isLoading: true)
                }
            }

            if self.currentLivePrompt.isEmpty {
                let randomPlaceholder = self.placeholders.randomElement() ?? "How can I help?"
                ResponseOverlayManager.shared.show(text: randomPlaceholder, isLoading: false)
            }
        }
    }

    func executeRequest(audioURL: URL?) async {
        guard !isProcessing else { return }
        isProcessing = true
        
        defer { isProcessing = false }
        
        let liveText = speech.stopLiveTranscription()
        
        let fallbackPrompt: String
        if let fileFallback = loadPrompt(name: "AGENT_FALLBACK_PROMPT.md") {
            fallbackPrompt = fileFallback
        } else {
            fallbackPrompt = "Analyze this screen and provide helpful context or answers about its content."
        }
        
        let prompt = !liveText.isEmpty ? liveText : (!currentLivePrompt.isEmpty ? currentLivePrompt : fallbackPrompt)
        currentLivePrompt = ""

        var augmentedPrompt = prompt 
        if let template = loadPrompt(name: "AGENT_REACT_PROMPT.md") {
            let inventory = SkillRegistry.shared.inventorySummary
            augmentedPrompt = template
                .replacingOccurrences(of: "{{inventory}}", with: inventory)
                .replacingOccurrences(of: "{{user_request}}", with: prompt)
        }

        print("[Agent] Augmented Prompt: \(augmentedPrompt)")
        HistoryStore.shared.appendMessage(HistoryMessage(role: "user", content: augmentedPrompt))
        ResponseOverlayManager.shared.show(text: "Thinking about: \(prompt)", isLoading: true)

        do {
            var imagesToSend: [Data] = []
            if let image = self.lastCapturedImage, let pngData = self.imageToPNG(image) {
                imagesToSend.append(pngData)
            }

            var fullResponse = ""
            for try await chunk in ollama.generateResponse(prompt: augmentedPrompt, images: imagesToSend) {
                fullResponse += chunk
                ResponseOverlayManager.shared.show(text: fullResponse, isLoading: true)
            }

            await handleActionIfPresent(response: fullResponse)
            
            ResponseOverlayManager.shared.show(text: fullResponse, isLoading: false)
            HistoryStore.shared.appendMessage(HistoryMessage(role: "assistant", content: fullResponse))
            print("[Agent] Ollama Response: \(fullResponse)")

        } catch {
            print("[Agent] Agent error: \(error)")
            let errorMsg = String(describing: error)
            ResponseOverlayManager.shared.show(text: "Error: \(errorMsg)", isLoading: false)
        }
    }

    private func loadPrompt(name: String) -> String? {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("sergey/Prompts/\(name)")
        return try? String(contentsOf: url, encoding: .utf8)
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

    private func imageToPNG(_ image: CGImage) -> Data? {
        let uiImage = NSImage(cgImage: image, size: .zero)
        guard let tiffData = uiImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
