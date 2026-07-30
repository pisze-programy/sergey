import Foundation
import FluidAudio
import Combine

enum ModelState {
    case idle
    case loading
    case ready
    case failed(message: String)
}

extension ModelState: Equatable {
    static func == (lhs: ModelState, rhs: ModelState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.ready, .ready): return true
        case (.failed(let lMsg), .failed(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

extension ModelState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .ready: return "Ready"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

final class ParakeetTranscriptionService {
    static let shared = ParakeetTranscriptionService()

    private let stateLock = NSLock()
    private var internalModelState: ModelState = .idle
    private var asrManagerInstance: AsrManager?

    private let modelStateSubject = PassthroughSubject<ModelState, Never>()

    func modelStatePublisher() -> AnyPublisher<ModelState, Never> {
        modelStateSubject.eraseToAnyPublisher()
    }

    var currentModelState: ModelState {
        stateLock.lock(); defer { stateLock.unlock() }
        return internalModelState
    }

    private init() {}

    private func getState() -> ModelState {
        stateLock.lock(); defer { stateLock.unlock() }
        return internalModelState
    }

    private nonisolated func setState(_ newState: ModelState) {
        stateLock.lock()
        internalModelState = newState
        stateLock.unlock()
        modelStateSubject.send(newState)
    }

    private func getAsrManager() -> AsrManager? {
        stateLock.lock(); defer { stateLock.unlock() }
        return asrManagerInstance
    }

    private nonisolated func setAsrManager(_ mgr: AsrManager, state: ModelState) {
        stateLock.lock()
        asrManagerInstance = mgr
        internalModelState = state
        stateLock.unlock()
        modelStateSubject.send(state)
    }

    func preloadModel() async {
        setState(.loading)

        Task.detached(priority: .utility) {
            do {
                let models = try await AsrModels.downloadAndLoad(
                    configuration: nil,
                    version: .v3
                )
                try? Task.checkCancellation()

                let manager = AsrManager(config: .default, models: nil)
                try await manager.loadModels(models)

                self.setAsrManager(manager, state: .ready)
            } catch {
                self.setState(.failed(message: error.localizedDescription))
            }
        }
    }

    func transcribe(samples: [Float], languageCode: String) async throws -> String {
        switch getState() {
        case .ready: break
        case .idle: _ = try await preloadModelAndInitialize()
        case .loading: try await waitForModelReady()
        case .failed(let message): throw TranscriptionError.modelNotReady(message)
        }

        guard !samples.isEmpty else { throw TranscriptionError.emptyInput }

        guard let manager = getAsrManager() else {
            throw TranscriptionError.modelNotReady("ASR manager not initialized")
        }

        var decoderState = TdtDecoderState.make()

        let result = try await manager.transcribe(
            samples,
            decoderState: &decoderState,
            language: Language(rawValue: languageCode)
        )

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }

        return text
    }

    private func preloadModelAndInitialize() async throws {
        setState(.loading)

        try await Task.detached(priority: .utility) {
            let models = try await AsrModels.downloadAndLoad(
                configuration: nil,
                version: .v3
            )

            let manager = AsrManager(config: .default, models: nil)
            try await manager.loadModels(models)

            self.setAsrManager(manager, state: .ready)
        }.value
    }

    private func waitForModelReady() async throws {
        let timeoutNanoseconds: UInt64 = 120 * NSEC_PER_SEC
        var waited: UInt64 = 0
        let interval: UInt64 = NSEC_PER_SEC / 2

        while waited < timeoutNanoseconds {
            switch getState() {
            case .ready: return
            case .failed(let message): throw TranscriptionError.modelNotReady(message)
            default:
                try await Task.sleep(nanoseconds: interval)
                waited += interval
            }
        }

        throw TranscriptionError.timeout
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotReady(String)
    case emptyInput
    case emptyResult
    case timeout

    var errorDescription: String? {
        switch self {
        case .modelNotReady(let msg): return "Model not ready: \(msg)"
        case .emptyInput: return "No audio samples provided"
        case .emptyResult: return "Transcription returned empty result"
        case .timeout: return "Timed out waiting for model to load"
        }
    }
}
