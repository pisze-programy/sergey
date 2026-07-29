import Foundation
import Combine
import SwiftUI

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
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = baseURL else {
                    continuation.finish(throwing: OllamaError.invalidConfiguration("Invalid URL in Settings"))
                    return
                }

                let messages: [[String: Any]] = [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt]
                ]

                let body: [String: Any] = [
                    "model": modelName,
                    "messages": messages,
                    "stream": false
                ]

                var request = URLRequest(url: url.appendingPathComponent("v1/chat/completions"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        let errorBody = String(data: data, encoding: .utf8)
                        continuation.finish(throwing: NSError(domain: "OllamaClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(statusCode)"]))
                        return
                    }

                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        continuation.yield(content)
                    } else {
                        continuation.finish(throwing: NSError(domain: "OllamaClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON mismatch"]))
                        return
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
