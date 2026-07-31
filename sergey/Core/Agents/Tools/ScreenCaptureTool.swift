import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

final class ScreenCaptureTool: AgentTool {
    let name = "screen_capture"
    let description = "Takes a screenshot of the entire screen and returns a TEXT description of its contents (via a vision model). Use this for any question about what is on the screen. Optional parameter: focus (string) — the user's request, so the description concentrates on relevant elements."

    func execute(parameters: [String: Any]) async throws -> String {
        let focus = parameters["focus"] as? String
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
            // Preprocess: raw Retina screenshots can be 5–13 MB PNGs. Vision
            // models downscale images internally anyway, so sending the full
            // file just wastes bandwidth and makes inference slow. Resize to a
            // max dimension and re-encode as JPEG (lossy ~q75) — typically
            // 50–100× smaller with no visible quality loss for the model.
            // The original PNG stays on disk (path reported to the agent).
            let optimized = Self.optimizedVisionData(from: path) ?? imageData
            let base64 = optimized.base64EncodedString()
            // Concise prompt: verbose vision descriptions blow up the agent's
            // context, slow down the main model and cause iteration exhaustion.
            var prompt = "You are analyzing a computer screen for an AI assistant. Describe what is visible with attention to visible text, numbers and UI elements. Be CONCISE and structured (short bullet list). Do NOT report the date or time shown anywhere on the screen — it may be misread; the assistant knows the correct time. If the image cannot be analyzed, say so in one sentence."
            if let focus = focus, !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                prompt += "\n\nThe user's request is: \"\(focus)\". Focus ONLY on the elements relevant to this request — quote the exact visible text, numbers, ratings, hours and UI elements that help answer it. Skip irrelevant chrome (menu bar, dock). Keep the whole description under ~250 words."
            }
            if let description = try? await OllamaClient().describeImage(base64: base64, model: SettingsStore.shared.visionModelName, prompt: prompt),
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines)
                // Safety cap so one bad capture can't flood the context.
                let capped = cleaned.count > 2500 ? String(cleaned.prefix(2500)) + "…" : cleaned
                result += "\nVisual analysis: \(capped)"
            }
        }
        return result
    }

    /// Loads the PNG, scales it down to at most `maxDimension` on the longest
    /// side and re-encodes as JPEG. Returns nil on any failure (caller falls
    /// back to whatever behavior is appropriate — vision is best-effort).
    private static func optimizedVisionData(
        from url: URL,
        maxDimension: CGFloat = 1280,
        jpegQuality: CGFloat = 0.75
    ) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        let scale = min(1, maxDimension / longest)
        let newWidth = max(1, Int(width * scale))
        let newHeight = max(1, Int(height * scale))

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        guard let resized = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: jpegQuality]
        CGImageDestinationAddImage(destination, resized, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }
}
