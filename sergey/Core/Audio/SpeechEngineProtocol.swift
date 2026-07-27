import Foundation
import AVFoundation

protocol SpeechEngine: AnyObject {
    func startLiveTranscription(onUpdate: @escaping (String) -> Void)
    func stopLiveTranscription() -> String
    func transcribe(audioURL: URL) async throws -> String
}
