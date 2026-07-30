import SwiftUI

struct SettingsAgentsView: View {
    @ObservedObject private var store = AgentDefinitionStore.shared

    @State private var selectedAgentID: UUID?
    @State private var editingCopy: AgentDefinitionModel?

    var body: some View {
        SettingsSplitPane {
            listSide
        } right: {
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

    private var listSide: some View {
        VStack(spacing: 0) {
            SettingsPageHeader("Agents") {
                Button {
                    let new = AgentDefinitionModel(
                        name: "", description: "", systemPrompt: "",
                        modelName: store.availableModels.first ?? ""
                    )
                    store.add(new)
                    selectedAgentID = new.id
                    editingCopy = new
                    store.reloadModels()
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            Divider()

            if store.definitions.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No agents defined yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        let new = AgentDefinitionModel(
                            name: "", description: "", systemPrompt: "",
                            modelName: store.availableModels.first ?? ""
                        )
                        store.add(new)
                        selectedAgentID = new.id
                        editingCopy = new
                    } label: {
                        Label("Add Agent", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Spacer()
                }
                .padding()
            } else {
                List(store.definitions, id: \.id, selection: $selectedAgentID) { def in
                    AgentListRowView(definition: def)
                }
                .listStyle(.plain)
            }
        }
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

struct AgentListRowView: View {
    let definition: AgentDefinitionModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 7, height: 7)

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

            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(definition.modelName)
                    .font(.system(size: 10).monospaced())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(nsColor: NSColor.controlBackgroundColor), in: Capsule())
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
