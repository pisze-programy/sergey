import Foundation
import Combine
import Speech
import AVFoundation

final class SpeechRecognizer {
    private(set) var activeEngine: SpeechEngine
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.activeEngine = SpeechRecognizer.createEngine()
        setupObservers()
    }

    private func setupObservers() {
        SettingsStore.shared.$sttEngineType
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateEngine()
            }
            .store(in: &cancellables)

        SettingsStore.shared.$speechLanguage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateEngine()
            }
            .store(in: &cancellables)
    }

    func updateEngine() {
        self.activeEngine = SpeechRecognizer.createEngine()
    }

    private static func createEngine() -> SpeechEngine {
        let type = SettingsStore.shared.sttEngineType
        
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
