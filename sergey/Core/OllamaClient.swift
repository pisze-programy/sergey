import Foundation

final class OllamaClient {
    private let baseURL = "http://localhost:11434/v1/chat/completions"
    private let apiBaseURL = URL(string: "http://localhost:11434")!
    
    func generateResponse(prompt: String, images: [Data] = [], model: String = "llava") async throws -> String {
        let base64Images = images.map { $0.base64EncodedString() }
        
        var userMessage: [String: Any] = [
            "role": "user",
            "content": prompt
        ]
        if !base64Images.isEmpty {
            userMessage["images"] = base64Images
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are Sergey, a helpful macOS AI assistant. Be concise and direct."],
                userMessage
            ],
            "stream": false
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        return content
    }
    
    func isAvailable() async -> Bool {
        var request = URLRequest(url: apiBaseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        
        return false
    }
}
