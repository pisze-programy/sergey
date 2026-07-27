import SwiftUI

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Voice")
                            .font(.headline)
                        Text("Allows the assistant to listen to your commands.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $store.enableVoice)
                        .labelsHidden()
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama URL")
                        .font(.headline)
                    Text("The endpoint where your local Ollama server is running.")
                            .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("URL", text: $store.ollamaURL)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Name")
                        .font(.headline)
                    Text("The specific model to use for processing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Model", text: $store.modelName)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("STT Engine")
                        .font(.headline)
                    Picker("Engine Type", selection: $store.sttEngineType) {
                        ForEach(STTEngineType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speech Language")
                        .font(.headline)
                    Picker("Language", selection: $store.speechLanguage) {
                        ForEach(SettingsStore.availableLanguages, id: \.id) { lang in
                            Text(lang.name).tag(lang.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Close") {
                        SettingsWindowManager.shared.hide()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .frame(width: 400)
    }
}

#Preview {
    SettingsView()
}
