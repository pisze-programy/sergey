import Foundation
import Combine

enum OllamaError: Error, LocalizedError {
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
            case .invalidConfiguration(let msg): return "Config Error: \(msg)"
        }
    }
}

final class OllamaClient {
    private var baseURL: URL? {
        let urlStr = SettingsStore.shared.ollamaURL
        guard !urlStr.isEmpty else { return nil }
        return URL(string: urlStr)
    }

    private var modelName: String {
        SettingsStore.shared.modelName
    }

    func generateResponse(systemPrompt: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        // Resolve config on the caller's context before the detached task, so the
        // stream producer never touches actor-isolated state (Swift 6-safe).
        let resolvedBaseURL = baseURL
        let resolvedModelName = modelName

        return AsyncThrowingStream { continuation in
            // Detached so the URLSession bytes + JSON parsing loop does not inherit
            // the caller's MainActor executor (up to 4 concurrent streams would
            // otherwise parse on the main thread).
            let task = Task.detached {
                guard let url = resolvedBaseURL else {
                    continuation.finish(throwing: OllamaError.invalidConfiguration("Invalid URL in Settings"))
                    return
                }

                let messages: [[String: Any]] = [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt]
                ]

                let body: [String: Any] = [
                    "model": resolvedModelName,
                    "messages": messages,
                    "stream": true
                ]

                var request = URLRequest(url: url.appendingPathComponent("v1/chat/completions"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: NSError(domain: "OllamaClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(statusCode)"]))
                        return
                    }

                    // Stream the NDJSON lines from the OpenAI-compatible endpoint,
                    // tolerating SSE framing ("data:"-prefixed lines, "[DONE]" terminator).
                    for try await line in bytes.lines {
                        var payload = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !payload.isEmpty else { continue }

                        // SSE framing: strip a leading "data:" prefix if present.
                        if payload.hasPrefix("data:") {
                            payload = String(payload.dropFirst("data:".count))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        }

                        // SSE end-of-stream marker.
                        if payload == "[DONE]" {
                            break
                        }

                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any] else {
                            continue
                        }

                        if let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(content)
                        }

                        if let finishReason = choices.first?["finish_reason"] as? String,
                           !finishReason.isEmpty, finishReason != "null" {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Sends an image to a vision-capable model and returns its description.
    func describeImage(base64: String, model: String, prompt: String) async throws -> String {
        guard let url = baseURL else {
            throw OllamaError.invalidConfiguration("Invalid URL in Settings")
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt,
                    "images": [base64]
                ]
            ],
            "stream": false
        ]
        var request = URLRequest(url: url.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Vision HTTP error \((response as? HTTPURLResponse)?.statusCode ?? 0)"])
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        throw NSError(domain: "OllamaClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Vision response JSON mismatch"])
    }

    func isAvailable() async -> Bool {
        guard let url = baseURL else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
