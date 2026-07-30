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
    @Published var sttEnabled: Bool = true {
        didSet { save() }
    }
    @Published var sttLanguageCode: String = "en" {
        didSet { save() }
    }
    @Published var sttAutoSubmit: Bool = false {
        didSet { save() }
    }
    @Published var sttSaveRecords: Bool = true {
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
            self.sttEnabled = decoded.sttEnabled ?? true
            self.sttLanguageCode = decoded.sttLanguageCode ?? "en"
            self.sttAutoSubmit = decoded.sttAutoSubmit ?? false
            self.sttSaveRecords = decoded.sttSaveRecords ?? true
        } else {
            self.ollamaURL = defaultURL
            self.modelName = defaultModel
            self.isFocusModeEnabled = false
            self.sttEnabled = true
            self.sttLanguageCode = "en"
            self.sttAutoSubmit = false
            self.sttSaveRecords = true
        }
    }

    private func save() {
        let data = SettingsData(
            ollamaURL: ollamaURL,
            modelName: modelName,
            isFocusModeEnabled: isFocusModeEnabled,
            sttEnabled: sttEnabled,
            sttLanguageCode: sttLanguageCode,
            sttAutoSubmit: sttAutoSubmit,
            sttSaveRecords: sttSaveRecords
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
    let sttEnabled: Bool?
    let sttLanguageCode: String?
    let sttAutoSubmit: Bool?
    let sttSaveRecords: Bool?
}
