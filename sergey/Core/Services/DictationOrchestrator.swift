import Foundation
import Combine
import SwiftUI
import OSLog

@MainActor
final class DictationOrchestrator: ObservableObject {
    static let shared = DictationOrchestrator()

    @Published var dictationStatus: DictationStatus = .idle
    @Published var currentAudioLevel: Double = 0

    var statusMessage: String {
        switch dictationStatus {
        case .idle: return "Ready"
        case .listening: return "Listening..."
        case .processing: return "Processing..."
        case .done: return "Transcription ready"
        case .error_(let msg): return msg
        }
    }

    private let log = Logger(subsystem: "sergey", category: "Dictation")
    private var cancellables = Set<AnyCancellable>()
    private let audioRecorder = AudioRecordingService.shared
    private let transcriptionService = ParakeetTranscriptionService.shared
    private let panel = StatusOverlayPanel.shared
    private let settings = SettingsStore.shared
    private var currentTaskID: UUID?
    private var livePreviewTask: Task<Void, Never>?

    private let minSamplesForTranscription = 8_000
    private let livePreviewInterval: UInt64 = 1_500_000_000
    private var lastLiveText: String = ""

    private init() {
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.currentAudioLevel = level
                self?.panel.currentAudioLevel = level
            }
            .store(in: &cancellables)

        $dictationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                self?.panel.isRecording = (newStatus == .listening)
            }
            .store(in: &cancellables)
    }

    var isBusy: Bool {
        switch dictationStatus {
        case .listening, .processing: return true
        case .idle, .done, .error_: return false
        }
    }

    func toggleRecording() {
        switch dictationStatus {
        case .idle, .error_: startRecording()
        case .listening: stopAndTranscribe()
        case .processing: break
        case .done: resetToIdle(); startRecording()
        }
    }

    func startRecording() {
        switch dictationStatus {
        case .idle, .error_: startDictation()
        case .done: resetToIdle(); startDictation()
        case .listening, .processing: break
        }
    }

    func stopAndTranscribe() {
        guard dictationStatus == .listening else { return }
        executeStopAndTranscribe()
    }

    func cancel() {
        livePreviewTask?.cancel()
        livePreviewTask = nil
        switch dictationStatus {
        case .listening:
            audioRecorder.cancelRecording()
            currentTaskID = nil
            resetToIdle()
        case .processing:
            currentTaskID = nil
            resetToIdle()
        case .done: resetToIdle()
        case .idle, .error_: break
        }
    }

    func forceCleanup() {
        livePreviewTask?.cancel()
        livePreviewTask = nil
        audioRecorder.cleanup()
        currentTaskID = nil
        resetToIdle()
    }

    private func startDictation() {
        guard settings.sttEnabled else { setError("STT disabled in settings"); return }
        guard currentTaskID == nil else { return }

        panel.userInput = ""
        lastLiveText = ""
        dictationStatus = .listening

        Task { @Sendable [weak self] in
            guard let self = self else { return }

            do {
                try await self.audioRecorder.startRecording()
                await self.startLivePreview()
            } catch {
                await MainActor.run {
                    self.setError("Failed to start recording: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startLivePreview() async {
        lastLiveText = ""
        livePreviewTask = Task { [weak self] in
            guard let self = self else { return }

            while dictationStatus == .listening {
                let samples = audioRecorder.getCurrentBuffer()
                if samples.count >= minSamplesForTranscription {
                    do {
                        let partial = try await transcriptionService.transcribe(
                            samples: samples,
                            languageCode: settings.sttLanguageCode
                        )
                        let trimmed = partial.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            await MainActor.run {
                                let diff: String
                                if trimmed.hasPrefix(self.lastLiveText) {
                                    diff = String(trimmed.dropFirst(self.lastLiveText.count)).trimmingCharacters(in: .whitespaces)
                                } else {
                                    diff = trimmed
                                }
                                if !diff.isEmpty {
                                    self.panel.userInput = diff
                                }
                                self.lastLiveText = trimmed
                            }
                        }
                    } catch {}
                }
                try? await Task.sleep(nanoseconds: livePreviewInterval)
            }
        }
    }

    private func executeStopAndTranscribe() {
        livePreviewTask?.cancel()
        livePreviewTask = nil

        let taskID = UUID()
        currentTaskID = taskID
        dictationStatus = .processing

        Task { @Sendable [weak self] in
            guard let self = self else { return }

            do {
                let samples = try await self.audioRecorder.stopRecording()
                let sampleCount = samples.count
                guard await self.isTaskStillCurrent(taskID) else { return }
                guard sampleCount >= self.minSamplesForTranscription else {
                    await MainActor.run {
                        guard self.currentTaskID == taskID else { return }
                        self.currentTaskID = nil
                        self.dictationStatus = .idle
                        self.panel.userInput = ""
                    }
                    return
                }

                let languageCode = self.settings.sttLanguageCode
                let transcript = try await self.transcriptionService.transcribe(
                    samples: samples,
                    languageCode: languageCode
                )

                guard await self.isTaskStillCurrent(taskID) else { return }

                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    await MainActor.run {
                        guard self.currentTaskID == taskID else { return }
                        self.currentTaskID = nil
                        self.dictationStatus = .idle
                        self.panel.userInput = ""
                    }
                    return
                }

                let duration = TimeInterval(sampleCount) / 16_000.0

                await MainActor.run { [trimmed, languageCode, duration] in
                    guard self.currentTaskID == taskID else { return }
                    self.currentTaskID = nil
                    if self.panel.userInput.isEmpty {
                        self.panel.userInput = trimmed
                    } else {
                        self.panel.userInput += " " + trimmed
                    }
                    self.dictationStatus = .done

                    let inserted = TextInsertionService.insertText(trimmed)
                    if self.settings.sttSaveRecords {
                        let record = STTRecord(
                            text: trimmed,
                            languageCode: languageCode,
                            duration: duration,
                            inserted: inserted
                        )
                        STTRecordStore.shared.append(record)
                    }

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if self.dictationStatus == .done {
                            self.panel.userInput = ""
                            self.resetToIdle()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    guard self.currentTaskID == taskID else { return }
                    self.currentTaskID = nil
                    self.setError("Transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func isTaskStillCurrent(_ taskID: UUID) async -> Bool {
        await MainActor.run { self.currentTaskID == taskID }
    }

    private func resetToIdle() {
        currentTaskID = nil
        dictationStatus = .idle
    }

    private func setError(_ message: String) {
        log.error("\(message)")
        currentTaskID = nil
        dictationStatus = .error_(message)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
            if case .error_(message) = self.dictationStatus {
                self.resetToIdle()
            }
        }
    }
}

enum DictationStatus: Equatable {
    case idle
    case listening
    case processing
    case done
    indirect case error_(String)

    var color: Color {
        switch self {
        case .idle: return .secondary
        case .listening: return .red
        case .processing: return .orange
        case .done: return .green
        case .error_: return .yellow
        }
    }

    var icon: String {
        switch self {
        case .idle: return "mic"
        case .listening: return "waveform.circle.fill"
        case .processing: return "brain.head.profile"
        case .done: return "checkmark.circle.fill"
        case .error_: return "exclamationmark.triangle.fill"
        }
    }
}
