import Foundation
import AVFoundation
import Combine
import OSLog

final class AudioRecordingService: ObservableObject {
    static let shared = AudioRecordingService()

    private let log = Logger(subsystem: "sergey", category: "AudioRecording")

    private let audioEngine = AVAudioEngine()
    private var recordingBuffer: [Float] = []
    private var audioConverter: AVAudioConverter?

    private let bufferQueue = DispatchQueue(label: "sergey.audio.buffer", qos: .userInitiated)

    private var _isRecording = false
    private let stateLock = NSLock()

    private var isRecording: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isRecording }
        set { stateLock.lock(); _isRecording = newValue; stateLock.unlock() }
    }

    @Published var audioLevel: Double = 0

    private init() {}

    func startRecording() async throws {
        guard !isRecording else { throw RecordingError.alreadyRecording }
        try await requestMicrophonePermission()

        try await MainActor.run {
            if audioEngine.isRunning { audioEngine.stop() }
            audioEngine.inputNode.removeTap(onBus: 0)

            bufferQueue.sync { recordingBuffer.removeAll() }
            audioConverter = nil

            let hardwareFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: 16_000,
                                             channels: 1,
                                             interleaved: false)!

            guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
                throw RecordingError.engineError("Failed to create audio converter")
            }
            self.audioConverter = converter

            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8192, format: nil) { [weak self] buffer, _ in
                guard let self = self, let converter = self.audioConverter else { return }

                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / hardwareFormat.sampleRate) + 1
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

                var error: NSError?
                var inputBuffer: AVAudioBuffer? = buffer
                let status = converter.convert(to: convertedBuffer, error: &error) { _, statusPtr in
                    if let input = inputBuffer {
                        inputBuffer = nil
                        statusPtr.pointee = .haveData
                        return input
                    }
                    statusPtr.pointee = .noDataNow
                    return nil
                }

                guard status != .error, convertedBuffer.frameLength > 0,
                      let channelData = convertedBuffer.floatChannelData else { return }
                let actualFrames = Int(convertedBuffer.frameLength)
                let ptr = channelData[0]
                let samples = Array(UnsafeBufferPointer(start: ptr, count: actualFrames))

                self.bufferQueue.sync {
                    self.recordingBuffer.append(contentsOf: samples)
                }

                var sumOfSquares: Float = 0
                for s in samples { sumOfSquares += s * s }
                let rms = actualFrames > 0 ? sqrt(sumOfSquares / Float(actualFrames)) : 0
                Task { @MainActor in self.audioLevel = Double(rms) }
            }

            Task { @MainActor in self.audioLevel = 0 }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true
        }
    }

    func stopRecording() async throws -> [Float] {
        guard isRecording else { throw RecordingError.notRecording }

        return try await MainActor.run {
            if audioEngine.isRunning { audioEngine.stop() }
            audioEngine.inputNode.removeTap(onBus: 0)
            audioConverter = nil

            let snapshot: [Float] = bufferQueue.sync {
                let copy = recordingBuffer
                recordingBuffer.removeAll()
                return copy
            }

            isRecording = false
            Task { @MainActor in self.audioLevel = 0 }
            return snapshot
        }
    }

    func getCurrentBuffer() -> [Float] {
        bufferQueue.sync { recordingBuffer }
    }

    func cancelRecording() {
        if Thread.isMainThread {
            performCancel()
        } else {
            DispatchQueue.main.sync { self.performCancel() }
        }
    }

    func cleanup() {
        cancelRecording()
    }

    private func performCancel() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioConverter = nil
        bufferQueue.sync { recordingBuffer.removeAll() }
        isRecording = false
        Task { @MainActor in self.audioLevel = 0 }
    }

    private func requestMicrophonePermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted { throw RecordingError.microphoneDenied }
        case .denied, .restricted:
            throw RecordingError.microphoneDenied
        default:
            break
        }
    }

    enum RecordingError: LocalizedError {
        case alreadyRecording
        case notRecording
        case microphoneDenied
        case engineError(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "Already recording."
            case .notRecording:     return "Not currently recording."
            case .microphoneDenied: return "Microphone access denied. Enable in System Settings > Privacy & Security > Microphone."
            case .engineError(let msg): return "Audio engine error: \(msg)"
            }
        }
    }
}
