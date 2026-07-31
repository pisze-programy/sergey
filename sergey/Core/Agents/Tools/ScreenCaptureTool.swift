import Foundation

final class ScreenCaptureTool: AgentTool {
    let name = "screen_capture"
    let description = "Takes a screenshot of the entire screen and saves it as a PNG; returns a visual description of the screen contents when a vision model is configured. No parameters."

    func execute(parameters: [String: Any]) async throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("sergey-screen-\(UUID().uuidString).png")

        let status = try await withThrowingTaskGroup(of: Int32.self) { group in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", path.path]
            // screencapture writes the PNG to the file path; stdout/stderr are unused.
            // Pointing them at the null device avoids a pipe deadlock if the child
            // ever writes more than the pipe buffer (64 KB).
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            // Timeout: if the capture hangs, terminate the process and report it.
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                process.terminate()
                throw NSError(
                    domain: "sergey.tools.screen_capture",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Screen capture timed out"]
                )
            }

            // Wait for the process to finish. The continuation is resumed exactly
            // once — either from the termination handler or from the run() error path.
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                    process.terminationHandler = { proc in
                        continuation.resume(returning: proc.terminationStatus)
                    }
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Race the two tasks: whichever finishes first wins; cancel the other.
            guard let first = try await group.next() else {
                throw NSError(
                    domain: "sergey.tools.screen_capture",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Screen capture failed to start"]
                )
            }
            group.cancelAll()
            return first
        }

        guard status == 0 else {
            throw NSError(
                domain: "sergey.tools.screen_capture",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "screencapture exited with status \(status)"]
            )
        }

        var result = "Screenshot saved to \(path.path)"
        if !SettingsStore.shared.visionModelName.isEmpty,
           let imageData = try? Data(contentsOf: path),
           !imageData.isEmpty {
            let base64 = imageData.base64EncodedString()
            let prompt = "Describe in detail what is visible on this computer screen. Mention windows, applications, text and UI elements you can recognize. If the image cannot be analyzed, say so."
            if let description = try? await OllamaClient().describeImage(base64: base64, model: SettingsStore.shared.visionModelName, prompt: prompt),
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result += "\nVisual analysis: \(description.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        }
        return result
    }
}
