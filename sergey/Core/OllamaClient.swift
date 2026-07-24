import Foundation

final class OllamaClient {
    private var baseURL: URL {
        if let saved = UserDefaults.standard.string(forKey: "OllamaBaseURL"), let url = URL(string: saved) {
            return url
        }
        return URL(string: "http://192.168.1.18:11434")!
    }

    func generateResponse(prompt: String, images: [Data] = [], model: String = "llama3.2-vision") async throws -> String {
        var userMessage: [String: Any] = ["role": "user", "content": prompt]
        if !images.isEmpty {
            userMessage["images"] = images.map { $0.base64EncodedString() }
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are Sergey, a helpful macOS AI assistant. Be concise and direct."],
                userMessage
            ],
            "stream": false
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(
                domain: "OllamaClient",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Ollama error (HTTP \(statusCode)): \(errorBody). Make sure Ollama is running (`ollama serve`) and model 'llava' is installed (`ollama pull llava`)."]
            )
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from Ollama"])
        }

        return content
    }

    func isAvailable() async -> Bool {
        var request = URLRequest(url: baseURL)
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
