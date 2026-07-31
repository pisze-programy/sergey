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
    @Published var sttSaveRecords: Bool = true {
        didSet { save() }
    }
    @Published var onboardingShown: Bool = false {
        didSet { save() }
    }
    @Published var visionModelName: String = "" {
        didSet { save() }
    }
    @Published var allowTextInsertion: Bool = false {
        didSet { save() }
    }
    @Published var allowBrowser: Bool = false {
        didSet {
            save()
            // `newValue` is unavailable in observers of wrapped properties;
            // `allowBrowser` already holds the new value here.
            if !allowBrowser {
                // Browser automation was just turned off — tear down any
                // self-launched Chrome so it doesn't keep running in the
                // background. A pre-existing external Chrome is never touched.
                BrowserSession.shared.shutdown()
            }
        }
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
            self.sttSaveRecords = decoded.sttSaveRecords ?? true
            self.onboardingShown = decoded.onboardingShown ?? false
            self.visionModelName = decoded.visionModelName ?? ""
            self.allowTextInsertion = decoded.allowTextInsertion ?? false
            self.allowBrowser = decoded.allowBrowser ?? false
        } else {
            self.ollamaURL = defaultURL
            self.modelName = defaultModel
            self.isFocusModeEnabled = false
            self.sttEnabled = true
            self.sttLanguageCode = "en"
            self.sttSaveRecords = true
            self.onboardingShown = false
            self.visionModelName = ""
            self.allowTextInsertion = false
            self.allowBrowser = false
        }
    }

    private func save() {
        let data = SettingsData(
            ollamaURL: ollamaURL,
            modelName: modelName,
            isFocusModeEnabled: isFocusModeEnabled,
            sttEnabled: sttEnabled,
            sttLanguageCode: sttLanguageCode,
            sttSaveRecords: sttSaveRecords,
            onboardingShown: onboardingShown,
            visionModelName: visionModelName,
            allowTextInsertion: allowTextInsertion,
            allowBrowser: allowBrowser
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
    let sttSaveRecords: Bool?
    let onboardingShown: Bool?
    let visionModelName: String?
    let allowTextInsertion: Bool?
    let allowBrowser: Bool?
}
