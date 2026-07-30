import SwiftUI

struct AgentEditorView: View {
    @Binding var definition: AgentDefinitionModel
    @ObservedObject private var store = AgentDefinitionStore.shared

    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                Divider()
                nameSection
                Divider()
                descriptionSection
                Divider()
                systemPromptSection
                Divider()
                modelSection
                footerActions
            }
            .padding(24)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.fill")
                .font(.title3)
                .foregroundColor(.blue)
            Text("Edit Agent")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "textformat")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Agent Name")
                    .font(.headline)
            }
            TextField(
                "e.g. Researcher",
                text: $definition.name,
                onCommit: { save() }
            )
            .textFieldStyle(.roundedBorder)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "quote.bubble")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Description")
                    .font(.headline)
            }
            Text("A short role description — when does this agent perform best?")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(
                "e.g. Investigates topics and synthesizes findings",
                text: $definition.description,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
        }
    }

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("System Prompt")
                    .font(.headline)
            }
            Text("The system prompt that defines this agent's behavior and capabilities.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(
                "You are a helpful assistant...",
                text: $definition.systemPrompt,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(6...20)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Model")
                    .font(.headline)
            }
            Text("The Ollama model this agent should use.")
                .font(.caption)
                .foregroundColor(.secondary)

            if store.availableModels.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Ollama unreachable or no models available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Retry") {
                        withAnimation { store.reloadModels() }
                    }
                    .font(.caption)
                }

                TextField(
                    "gemma4:26mu-a4b-it-q4_K_M",
                    text: $definition.modelName,
                    onCommit: { save() }
                )
                .textFieldStyle(.roundedBorder)
            } else {
                Menu {
                    ForEach(store.availableModels, id: \.self) { model in
                        Button(model) {
                            definition.modelName = model
                            save()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(definition.modelName.isEmpty ? "Select a model..." : definition.modelName)
                            .foregroundColor(definition.modelName.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            Spacer()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Agent"),
                    message: Text("Are you sure you want to delete \"\(definition.name.isEmpty ? "Unnamed Agent" : definition.name)\"? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        store.delete(id: definition.id)
                    },
                    secondaryButton: .cancel()
                )
            }

            Button {
                save()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func save() {
        store.update(definition)
    }
}
