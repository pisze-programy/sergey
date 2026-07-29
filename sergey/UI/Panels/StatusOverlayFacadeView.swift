import SwiftUI

struct AgentRowComponent: View {
    let agent: AgentModel
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(agent.state.color)
                    .frame(width: agent.state == .running ? 16 : 10, height: agent.state == .running ? 16 : 10)
                    .opacity(0.3)

                Circle()
                    .fill(agent.state.color)
                    .frame(width: 9, height: 9)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                Text(agent.workDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(agent.state.title)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.8).opacity(0.65))
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(11)
    }
}

struct AgentListView: View {
    let agents: [AgentModel]
    let onTap: (AgentModel) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(agents) { agent in
                    Button {
                        onTap(agent)
                    } label: {
                        AgentRowComponent(agent: agent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct EmptyStateAgentView: View {
    var body: some View {
        ContentUnavailableView(
            "No agents",
            systemImage: "person.crop.circle.badge.questionmark",
            description: Text("Agents managing active tasks will appear here.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatusOverlayFacadeView: View {
    @EnvironmentObject var statusService: AgentStatusService
    @ObservedObject private var panelManager = StatusOverlayPanel.shared
    @State private var selectedAgentId: UUID?
    @FocusState private var isInputFieldFocused: Bool
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        rootContent()
            .frame(width: StatusOverlayPanel.Layout.width, height: panelManager.isExpanded ? StatusOverlayPanel.Layout.expandedHeight : StatusOverlayPanel.Layout.collapsedHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: panelManager.isExpanded)
            .opacity(settings.isFocusModeEnabled ? 0.5 : 1.0)
            .onChange(of: panelManager.isExpanded) { expanded in
                if expanded {
                    isInputFieldFocused = true
                }
            }
    }
    
    @ViewBuilder
    private func rootContent() -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )

            VStack(spacing: 0) {
                StatusOverlayHeaderViewView(
                    isActive: true,
                    statusMessage: statusService.statusMessage,
                    isExpanded: panelManager.isExpanded,
                    onTap: toggleHeader
                )
                
                if panelManager.isExpanded {
                    self.expandedContent()
                        .padding(15)
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    @ViewBuilder
    private func expandedContent() -> some View {
        VStack(spacing: 15) {
            inputField()

            Divider()
                .padding(.vertical, 5)
                .opacity(0.3)
            
            agentContent
        }
    }
    
    @ViewBuilder
    private func inputField() -> some View {
        HStack {
            Image(systemName: "terminal")
                .foregroundColor(.secondary)
            
            TextField("Command...", text: $panelManager.userInput, onCommit: {})
                .textFieldStyle(.plain)
                .focused($isInputFieldFocused)
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var agentContent: some View {
        if let selectedId = selectedAgentId {
            AgentDetailViewDetailPanel(agentId: selectedId, onBack: {
                self.selectedAgentId = nil
            })
            .environmentObject(statusService)
        } else if statusService.activeAgents.isEmpty {
            EmptyStateAgentView()
        } else {
            AgentListView(agents: statusService.activeAgents) { agent in
                isInputFieldFocused = false
                selectedAgentId = agent.id
            }
        }
    }
    
    private func toggleHeader() {
        selectedAgentId = nil
        panelManager.toggleExpansion()
    }
}
