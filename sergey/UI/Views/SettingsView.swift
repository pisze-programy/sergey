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

                // STT/Voice options removed. Use other input methods.

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

                Toggle(isOn: $store.isFocusModeEnabled) {
                    Text("Focus Mode")
                        .font(.headline)
                }
                .help("Suppress overlay updates. Only critical notifications are shown.")

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
