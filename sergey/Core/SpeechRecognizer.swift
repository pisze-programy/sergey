import Foundation
import Speech
import AVFoundation

final class SpeechRecognizer {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pl-PL"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var liveTranscriptionText: String = ""

    func startLiveTranscription(onUpdate: @escaping (String) -> Void) {
        stopLiveTranscription()
        liveTranscriptionText = ""

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ SpeechRecognizer: Recognizer not available")
            return
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        // Use the format of the input node itself for the tap
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            guard let request = request else { return }
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("✅ SpeechRecognizer: Audio engine started")
        } catch {
            print("❌ SpeechRecognizer: Audio engine start error: \(error)")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error = error {
                let nsError = error as NSError
                // Error 216 or cancellation-related errors are expected when we manually stop the task
                if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 216 || nsError.code == -101) {
                    print("ℹ️ SpeechRecognizer: Recognition session ended (normal).")
                } else {
                    print("❌ SpeechRecognizer: Recognition error: \(error)")
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
        recognitionTask?.cancel()
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
            throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
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
