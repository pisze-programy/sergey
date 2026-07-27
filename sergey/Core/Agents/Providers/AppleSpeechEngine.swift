import Foundation
import AVFoundation
import Speech

final class AppleSpeechEngine: SpeechEngine {
    private let speechRecognizer: SFSpeechRecognizer?

    init(language: String = "pl-PL") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
    }

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var liveTranscriptionText: String = ""

    func startLiveTranscription(onUpdate: @escaping (String) -> Void) {
        _ = stopLiveTranscription()
        liveTranscriptionText = ""

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("AppleSpeechEngine: Recognizer not available")
            return
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            guard let request = request else { return }
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("AppleSpeechEngine error: \(error)")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error = error {
                let nsError = error as NSError
                let isIgnorable = (nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 216 || nsError.code == -101)) ||
                                  (nsError.domain == "kLSRErrorDomain" && nsError.code == 301)
                if !isIgnorable {
                    print("AppleSpeechEngine error: \(error)")
                }
                return
            }
            if let result = result {
                let text = result.bestTranscription.formattedString
                self?.liveTranscriptionText = text
                onUpdate(text)
            }
        }
    }

    func stopLiveTranscription() -> String {
        let final = liveTranscriptionText
        liveTranscriptionText = ""

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            audioEngine = nil
        }
        
        return final
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "AppleSpeechEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
