import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    
    // Placeholder states
    @State private var ollamaURL = "http://localhost:11434"
    @State private var modelName = "gemma4:26b-a4b-it-q4_K_M"
    @State private var enableVoice = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)

            // Row 1: Label + Desc (left), Toggle (right)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Voice")
                        .font(.headline)
                    Text("Allows the assistant to listen to your commands.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $enableVoice)
                    .labelsHidden()
            }

            Divider()

            // Row 2: Label + Desc, TextField below
            VStack(alignment: .leading, spacing: 4) {
                Text("Ollama URL")
                    .font(.headline)
                Text("The endpoint where your local Ollama server is running.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("URL", text: $ollamaURL)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Row 3: Label + Desc, TextField below
            VStack(alignment: .leading, spacing: 4) {
                Text("Model Name")
                    .font(.headline)
                Text("The specific model to use for processing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
                TextField("Model", text: $modelName)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 10)
        }
        .padding(24)
        .frame(width: 400)
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}
