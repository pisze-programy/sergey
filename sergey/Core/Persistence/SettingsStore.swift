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
    @Published var isFocusModeEnabled: Bool = false {
        didSet { save() }
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".sergey_config.json")
        self.configURL = configPath

        let defaultURL = "http://localhost:11434"
        let defaultModel = "gemma4:26mu-a4b-it-q4_K_M"

        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) {
            self.ollamaURL = decoded.ollamaURL
            self.modelName = decoded.modelName
            self.isFocusModeEnabled = decoded.isFocusModeEnabled
        } else {
            self.ollamaURL = defaultURL
            self.modelName = defaultModel
            self.isFocusModeEnabled = false
        }
    }

    private func save() {
        let data = SettingsData(
            ollamaURL: ollamaURL,
            modelName: modelName,
            isFocusModeEnabled: isFocusModeEnabled
        )
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: configURL)
        }
    }
}

struct SettingsData: Codable {
    let ollamaURL: String
    let modelName: String
    let isFocusModeEnabled: Bool
}
