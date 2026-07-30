import SwiftUI

struct SettingsGeneralView: View {
    @ObservedObject var store = SettingsStore.shared

    var body: some View {
        SettingsPane("General") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsSectionContainer("Ollama Connection", subtitle: "The endpoint where your local Ollama server is running.") {
                        SettingsTextFieldRow("Server URL", placeholder: "http://localhost:11434", text: $store.ollamaURL)
                        SettingsTextFieldRow("Default Model", subtitle: "The specific model to use for processing.", placeholder: "gemma4:26mu-a4b-it-q4_K_M", text: $store.modelName)
                    }

                    SettingsSectionContainer("Speech-to-Text", subtitle: "Offline voice dictation using Parakeet TDT v3.") {
                        SettingsToggleRow("Enable Dictation", isOn: $store.sttEnabled)
                        SettingsPickerRow(selection: $store.sttLanguageCode, disabled: !store.sttEnabled) {
                            Text("Language")
                        } content: {
                            Text("English").tag("en")
                            Text("Polski").tag("pl")
                        }
                        SettingsToggleRow("Auto-send to LLM on Transcribe Finish", isOn: $store.sttAutoSubmit, disabled: !store.sttEnabled)
                        SettingsToggleRow("Save Records", subtitle: "Keep a history of all dictations.", isOn: $store.sttSaveRecords, disabled: !store.sttEnabled)
                    }

                    SettingsSectionContainer("Focus Mode") {
                        SettingsToggleRow("Focus Mode", subtitle: "Suppress overlay updates. Only critical notifications are shown.", isOn: $store.isFocusModeEnabled)
                    }
                }
                .padding(24)
            }
        }
    }
}
