import Foundation

final class OllamaClient {
    private var baseURL: URL {
        if let envURL = ProcessInfo.processInfo.environment["OLLAMA_URL"], let url = URL(string: envURL) {
            return url
        }
        if let saved = UserDefaults.standard.string(forKey: "OllamaBaseURL"), let url = URL(string: saved) {
            return url
        }
        return URL(string: "http://localhost:11434")!
    }

    func generateResponse(prompt: String, images: [Data] = [], model: String = "gemma4:26b-a4b-it-q4_K_M") -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                print("[OllamaClient] Generating response (non-streaming). Model: \(model)")
                
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
                    ["role": "system", "content": "You are Sergey, a concise macOS assistant. Provide the shortest possible correct answer. Avoid all conversational filler, introductions, and conclusions. Use markdown bullets for lists as needed."],
                    ["role": "user", "content": contentParts]
                ]

                let body: [String: Any] = [
                    "model": model,
                    "messages": messages,
                    "stream": false
                ]

                var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: NSError(domain: "OllamaClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "HTTP error"]))
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
        print("[OllamaClient] Checking availability at \(baseURL)...")
        var request = URLRequest(url: baseURL)
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
