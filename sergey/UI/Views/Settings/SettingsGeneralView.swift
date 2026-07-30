import SwiftUI

struct SettingsGeneralView: View {
    @ObservedObject var store = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("General")
                    .font(.title2)
                    .fontWeight(.semibold)

                Divider()

                connectionSection
                modelSection
                dividerOrnament
                focusModeSection
            }
            .padding(24)
        }
    }

    // MARK: - Sections

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ollama Connection")
                .font(.headline)
            Text("The endpoint where your local Ollama server is running.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("http://localhost:11434", text: $store.ollamaURL)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Default Model")
                .font(.headline)
            Text("The specific model to use for processing.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("gemma4:26mu-a4b-it-q4_K_M", text: $store.modelName)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
        }
    }

    private var focusModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $store.isFocusModeEnabled) {
                Text("Focus Mode")
                    .font(.headline)
            }
            Text("Suppress overlay updates. Only critical notifications are shown.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var dividerOrnament: some View {
        Divider()
    }
}
