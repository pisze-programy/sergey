import Foundation
import Speech
import AVFoundation

final class SpeechRecognizer {
    enum EngineType {
        case appleNative
        case parakeet
    }

    private(set) var activeEngine: SpeechEngine

    init(type: EngineType = .appleNative) {
        switch type {
        case .appleNative:
            self.activeEngine = AppleSpeechEngine()
        case .parakeet:
            self.activeEngine = ParakeintSpeechEngine()
        }
    }

    func startLiveTranscription(onUpdate: @escaping (String) -> Void) {
        activeEngine.startLiveTranscription(onUpdate: onUpdate)
    }

    func stopLiveTranscription() -> String {
        return activeEngine.stopLiveTranscription()
    }

    func transcribe(audioURL: URL) async throws -> String {
        return try await activeEngine.transcribe(audioURL: audioURL)
    }
}
