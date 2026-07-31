import SwiftUI

struct AgentEditorView: View {
    @Binding var definition: AgentDefinitionModel
    @ObservedObject private var store = AgentDefinitionStore.shared

    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit Agent")
                    .font(.title2)
                    .fontWeight(.semibold)

                SettingsDivider()

                SettingsSectionContainer("Agent Name") {
                    SettingsTextFieldRow("", placeholder: "e.g. Researcher", text: $definition.name)
                }

                SettingsSectionContainer("Description", subtitle: "A short role description — when does this agent perform best?") {
                    TextField("e.g. Investigates topics and synthesizes findings",
                              text: $definition.description,
                              axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                }

                SettingsSectionContainer("System Prompt", subtitle: "The system prompt that defines this agent's behavior and capabilities.") {
                    TextField("You are a helpful assistant...",
                              text: $definition.systemPrompt,
                              axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(6...20)
                }

                SettingsSectionContainer("Model", subtitle: "The Ollama model this agent should use.") {
                    modelSelector
                }

                footerActions
            }
            .padding(24)
        }
    }

    private var modelSelector: some View {
        Group {
            if store.availableModels.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Ollama unreachable or no models available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Retry") {
                        withAnimation { store.refreshModels() }
                    }
                    .font(.caption)
                }
                TextField("gemma4:26mu-a4b-it-q4_K_M",
                          text: $definition.modelName,
                          onCommit: { save() })
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
