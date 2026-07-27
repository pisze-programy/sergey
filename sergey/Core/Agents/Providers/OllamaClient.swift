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

    func generateResponse(systemPrompt: String, prompt: String, images: [Data] = []) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = baseURL else {
                    continuation.finish(throwing: OllamaError.invalidConfiguration("Invalid URL in Settings"))
                    return
                }
                
                var contentParts: [[String: Any]] = [["type": "text", "text": prompt]]
                if !images.isEmpty {
                    for imageData in images {
                        let base64Image = imageData.base64EncodedString()
                        contentParts.append([
                            "type": "image_url",
                            "image_url": ["url": "data:image/png;base64,\(base64Image)"]
                        ])
                    }
                }

                let messages: [[String: Any]] = [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": contentParts]
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
                        let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                        print("[OllamaClient] HTTP Error \(statusCode): \(errorBody)")
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
                    print("[OllamaClient] Request error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func isAvailable() async -> Bool {
        guard let url = baseURL else { return false }
        print("[OllamaClient] Checking availability at \(url)...")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            print("[OllamaClient] Availability check: \(ok ? "UP" : "DOWN")")
            return ok
        } catch {
            print("[OllamaClient] Availability error: \(error)")
            return false
        }
    }
}
