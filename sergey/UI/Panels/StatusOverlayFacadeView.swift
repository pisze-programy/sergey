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

private enum InputFieldFocus: Hashable {
    case input
}

struct StatusOverlayFacadeView: View {
    @EnvironmentObject var statusService: AgentStatusService
    @ObservedObject private var panelManager = StatusOverlayPanel.shared
    @State private var selectedAgentId: UUID?
    @FocusState private var focusedField: InputFieldFocus?
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var orchestrator = DictationOrchestrator.shared
    @ObservedObject private var healthService = OllamaHealthService.shared

    private var micIconName: String {
        switch orchestrator.dictationStatus {
        case .idle: return "mic"
        case .listening: return "waveform.circle.fill"
        case .processing: return "brain.head.profile"
        case .done: return "checkmark.seal.fill"
        case .error_: return "exclamationmark.triangle.fill"
        }
    }

    private var micColor: Color {
        switch orchestrator.dictationStatus {
        case .idle: return .secondary
        case .listening: return .red
        case .processing: return .orange
        case .done: return .green
        case .error_: return .yellow
        }
    }

    private var headerMessage: String {
        switch orchestrator.dictationStatus {
        case .idle:
            return statusService.statusMessage
        case .listening:
            let text = orchestrator.livePreviewText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Listening..." : text
        case .processing:
            return "Processing..."
        case .done:
            return "Transcription ready"
        case .error_(let msg):
            return msg
        }
    }

    private var isDictationActive: Bool {
        orchestrator.dictationStatus != .idle
    }

    private var placeholderText: String { "Command..." }

    var body: some View {
        rootContent()
            .frame(
                width: StatusOverlayPanel.Layout.width,
                height: panelManager.isExpanded
                    ? StatusOverlayPanel.Layout.expandedHeight
                    : StatusOverlayPanel.Layout.collapsedHeight,
                alignment: .top
            )
            .clipped()
            .background(
                RoundedRectangle(cornerRadius: StatusOverlayPanel.Layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
            )
            .opacity(settings.isFocusModeEnabled ? 0.5 : 1.0)
            .onChange(of: panelManager.isExpanded) { expanded in
                if expanded { focusedField = .input }
            }
    }

    @ViewBuilder
    private func rootContent() -> some View {
        VStack(spacing: 0) {
            StatusOverlayHeaderViewView(
                isActive: healthService.isHealthy,
                statusMessage: headerMessage,
                isExpanded: panelManager.isExpanded,
                onTap: toggleHeader,
                targetAppIcon: orchestrator.targetAppIcon,
                targetAppName: orchestrator.targetAppName,
                isDictationActive: isDictationActive
            )
            .overlay(alignment: .trailing) {
                if isDictationActive {
                    dictationHeaderIndicator
                        .padding(.trailing, 40)
                }
            }

            if panelManager.isExpanded {
                expandedContent()
                    .padding(15)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: panelManager.isExpanded)
    }

    private var dictationHeaderIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: micIconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(micColor)

            if case .listening = orchestrator.dictationStatus {
                audioLevelPulse
            }
        }
    }

    private var audioLevelPulse: some View {
        let level = min(panelManager.currentAudioLevel * 3, 1.0)
        return Circle()
            .fill(micColor)
            .frame(width: 8, height: 8)
            .opacity(0.3 + 0.7 * level)
            .scaleEffect(0.8 + 0.4 * level)
            .animation(.easeInOut(duration: 0.08), value: level)
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
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            TextField(placeholderText, text: $panelManager.userInput, onCommit: {})
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .input)
                .font(.system(size: 14))
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
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
                focusedField = nil
                selectedAgentId = agent.id
            }
        }
    }

    private func toggleHeader() {
        selectedAgentId = nil
        panelManager.toggleExpansion()
    }
}
