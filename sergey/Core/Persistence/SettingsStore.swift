import Foundation
import Combine
import SwiftUI

struct Language: Identifiable, Hashable {
    let id: String // BCP 47 tag
    let name: String
}

enum STTEngineType: String, Codable, CaseIterable {
    case apple = "AppleSpeechEngine"
    case parakeet = "ParakeetSpeechEngine"
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    static let availableLanguages: [Language] = [
        Language(id: "pl-PL", name: "Polski"),
        Language(id: "en-US", name: "English"),
        Language(id: "de-DE", name: "Deutsch"),
        Language(id: "fr-FR", name: "Français"),
        Language(id: "es-ES", name: "Español"),
        Language(id: "it-IT", name: "Italiano"),
        Language(id: "ru-RU", name: "Русский"),
        Language(id: "zh-CN", name: "中文"),
        Language(id: "ja-JP", name: "日本語"),
        Language(id: "pt-BR", name: "Português")
    ]

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
    @Published var sttEngineType: STTEngineType {
        didSet { 
            print("[SettingsStore] sttEngineType changed to: \(sttEngineType)")
            save() 
        }
    }
    @Published var speechLanguage: String {
        didSet { save() }
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".sergey_config.json")
        self.configURL = configPath

        let defaultURL = "http://localhost:11434"
        let defaultModel = "gemma4:26mu-a4b-it-q4_K_M"
        let defaultVoice = true
        let defaultEngine = STTEngineType.apple
        let defaultLang = "pl-PL"

        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) {
            self.ollamaURL = decoded.ollamaURL
            self.modelName = decoded.modelName
            self.enableVoice = decoded.enableVoice
            // Fallback for old string-based engine type during migration
            if let engine = STTEngineType(rawValue: decoded.sttEngineType) {
                self.sttEngineType = engine
            } else {
                self.sttEngineType = defaultEngine
            }
            self.speechLanguage = decoded.speechLanguage
        } else {
            self.ollamaURL = defaultURL
            self.modelName = defaultModel
            self.enableVoice = defaultVoice
            self.sttEngineType = defaultEngine
            self.speechLanguage = defaultLang
        }
    }

    private func save() {
        let dataToSave = SettingsData(
            ollamaURL: ollamaURL,
            modelName: modelName,
            enableVoice: enableVoice,
            sttEngineType: sttEngineType.rawValue,
            speechLanguage: speechLanguage
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

struct SettingsData: Codable {
    let ollamaURL: String
    let modelName: String
    let enableVoice: Bool
    let sttEngineType: String
    let speechLanguage: String
}
