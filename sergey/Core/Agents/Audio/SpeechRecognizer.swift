import Foundation
import Speech
import AVFoundation

final class SpeechRecognizer {
    private(set) var activeEngine: SpeechEngine

    init() {
        self.activeEngine = SpeechRecognizer.createEngine()
    }

    func updateEngine() {
        print("[SpeechRecognizer] Called updateEngine()")
        self.activeEngine = SpeechRecognizer.createEngine()
    }

    private static func createEngine() -> SpeechEngine {
        let type = SettingsStore.shared.sttEngineType
        print("[SpeechRecognizer] Creating engine for type: \(type)")
        switch type {
        case .apple:
            return AppleSpeechEngine(language: SettingsStore.shared.speechLanguage)
        case .parakeet:
            return ParakeetSpeechEngine()
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
