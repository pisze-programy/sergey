import Foundation
import Combine
import SwiftUI

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let configURL: URL

    @Published var ollamaURL: String {
        didSet { save() }
    }
    @Published var modelName: String {
        didSet { save() }
    }
    @Published var enableVoice: Bool {
        didSet { save() }
    }

    private init() {
        // Permanent storage in the user's home directory (~/.sergey_config.json)
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configURL = home.appendingPathComponent(".sergey_config.json")

        // Default values
        let defaultURL = "http://localhost:11434"
        let defaultModel = "gemma4:26b-a4b-it-q4_K_M"
        let defaultVoice = true

        // Attempt to load from file
        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) {
            self.ollamaURL = decoded.ollamaURL
            self.modelName = decoded.modelName
            self.enableVoice = decoded.enableVoice
        } else {
            // Fallback to defaults if file doesn't exist or is invalid
            self.ollamaURL = defaultURL
            self.modelName = defaultModel
            self.enableVoice = defaultVoice
        }
    }

    private func save() {
        let dataToSave = SettingsData(
            ollamaURL: ollamaURL,
            modelName: modelName,
            enableVoice: enableVoice
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encoded = try encoder.encode(dataToSave)
            try encoded.write(to: configURL)
            print("[SettingsStore] Saved configuration to \(configURL.path)")
        } catch {
            print("[SettingsStore] Failed to save configuration: \(error)")
        }
    }
}

// Codable helper for JSON serialization
struct SettingsData: Codable {
    let ollamaURL: String
    let modelName: String
    let enableVoice: Bool
}
