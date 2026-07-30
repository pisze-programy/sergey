import SwiftUI

struct SettingsAgentsView: View {
    @ObservedObject private var store = AgentDefinitionStore.shared

    @State private var selectedAgentID: UUID?
    @State private var editingCopy: AgentDefinitionModel?

    private var currentDefinition: AgentDefinitionModel? {
        if let id = selectedAgentID {
            return store.definitions.first(where: { $0.id == id })
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            agentsList
                .frame(width: 320)

            Divider()
                .padding(.vertical, 8)

            if let def = editingCopy {
                AgentEditorView(definition: Binding(
                    get: { def },
                    set: { editingCopy = $0 }
                ))
            } else {
                detailPlaceholder
            }
        }
        .onChange(of: selectedAgentID) { _, newId in
            if let id = newId, let source = store.definitions.first(where: { $0.id == id }) {
                editingCopy = source
            } else {
                editingCopy = nil
            }
        }
    }

    // MARK: - List

    private var agentsList: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()
            if store.definitions.isEmpty {
                emptyState
            } else {
                List(store.definitions, id: \.id, selection: $selectedAgentID) { def in
                    AgentListRowView(definition: def)
                }
                .listStyle(.plain)
            }
        }
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .foregroundColor(.blue)
            Text("Agents")
                .font(.headline)
            Spacer()
            Button {
                let new = AgentDefinitionModel(
                    name: "",
                    description: "",
                    systemPrompt: "",
                    modelName: store.availableModels.first ?? ""
                )
                store.add(new)
                selectedAgentID = new.id
                editingCopy = new
                store.reloadModels()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No agents defined yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                let new = AgentDefinitionModel(
                    name: "",
                    description: "",
                    systemPrompt: "",
                    modelName: store.availableModels.first ?? ""
                )
                store.add(new)
                selectedAgentID = new.id
                editingCopy = new
            } label: {
                Label("Add Agent", systemImage: "plus")
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }

    private var detailPlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "pencil")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Select an agent to edit")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - List Row

struct AgentListRowView: View {
    let definition: AgentDefinitionModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(definition.name.isEmpty ? "Unnamed" : definition.name)
                    .font(.system(size: 13, weight: .medium))
                if !definition.description.isEmpty {
                    Text(definition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "cpu")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(definition.modelName)
                    .font(.system(size: 9).monospaced())
                    .foregroundColor(.secondary)
            }
        }
    }
}
