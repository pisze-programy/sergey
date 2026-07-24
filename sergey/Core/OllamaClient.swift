import Foundation

final class OllamaClient {
    private var baseURL: URL {
        if let saved = UserDefaults.standard.string(forKey: "OllamaBaseURL"), let url = URL(string: saved) {
            return url
        }
        return URL(string: "http://192.168.1.18:11434")!
    }

    func generateResponse(prompt: String, images: [Data] = [], model: String = "gemma4:26b-a4b-it-q4_K_M") async throws -> String {
        print("🚀 [OllamaClient] Generating response. Model: \(model), Prompt snippet: \"\(prompt.prefix(50))...\"")
        
        var contentParts: [[String: Any]] = [["type": "text", "text": prompt]]
        if !images.isEmpty {
            print("🖼️ [OllamaClient] Attaching \(images.count) images to request.")
            for imageData in images {
                let base64Image = imageData.base64EncodedString()
                contentParts.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                ])
            }
        }

        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are Sergey, a helpful macOS AI assistant. Be concise and direct."],
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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🌐 [OllamaClient] Sending POST to \(request.url?.absoluteString ?? "unknown URL")")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [OllamaClient] No HTTP response.")
            throw NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }

        print("📥 [OllamaClient] Response Status: \(httpResponse.statusCode), Size: \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ [OllamaClient] Server Error: \(errorBody)")
            throw NSError(
                domain: "OllamaClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Ollama error (HTTP \(httpResponse.statusCode)): \(errorBody)"]
            )
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("❌ [OllamaClient] Failed to parse JSON structure.")
            throw NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from Ollama"])
        }

        return content
    }

    func isAvailable() async -> Bool {
        print("🔍 [OllamaClient] Checking availability at \(baseURL)...")
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            print("✅ [OllamaClient] Availability check: \(ok ? "UP" : "DOWN")")
            return ok
        } catch {
            print("❌ [OllamaClient] Availability error: \(error)")
            return false
        }
    }
}
