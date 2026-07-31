import SwiftUI

struct QueueEntryRow: View {
    let task: QueuedTask

    private var statusColor: Color {
        switch task.status {
        case .running: return .green
        case .pending, .scheduled: return .gray
        case .completed: return .blue
        case .failed: return .red
        }
    }

    private var statusTitle: String {
        switch task.status {
        case .pending: return "Queued"
        case .scheduled: return "Scheduled"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    private var subtitle: String {
        switch task.status {
        case .running:
            return task.prompt
        case .pending:
            return "Queued · priority \(task.priority)"
        case .scheduled:
            return "Scheduled"
        case .completed:
            return "Completed"
        case .failed:
            return task.failureReason ?? "Failed"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: task.status == .running ? 16 : 10, height: task.status == .running ? 16 : 10)
                    .opacity(0.3)

                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(statusTitle)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.8).opacity(0.65))
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(11)
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
    @EnvironmentObject private var queueManager: TaskQueueManager
    @State private var selectedAgentId: UUID?
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
        agentContent
            .padding(15)
    }

    @ViewBuilder
    private var agentContent: some View {
        if let selectedId = selectedAgentId {
            AgentDetailViewDetailPanel(agentId: selectedId, onBack: {
                self.selectedAgentId = nil
            })
            .environmentObject(statusService)
        } else if queueManager.tasks.isEmpty {
            EmptyStateAgentView()
        } else {
            queueListView
        }
    }

    private var queueEntries: [QueuedTask] {
        let running = queueManager.tasks.filter { $0.status == .running }
        let queued = queueManager.tasks
            .filter { $0.status == .pending || $0.status == .scheduled }
            .sorted { task1, task2 in
                if task1.priority != task2.priority { return task1.priority > task2.priority }
                return task1.createdAt < task2.createdAt
            }
        let finished = queueManager.tasks
            .filter { $0.status == .completed || $0.status == .failed }
            .sorted { $0.createdAt > $1.createdAt }
        return Array((running + queued + finished).prefix(50))
    }

    private var queueListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(queueEntries) { task in
                    Button {
                        guard let agentId = task.assignedToAgentId,
                              statusService.activeAgents.contains(where: { $0.id == agentId }) else {
                            return
                        }
                        selectedAgentId = agentId
                    } label: {
                        QueueEntryRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func toggleHeader() {
        selectedAgentId = nil
        panelManager.toggleExpansion()
    }
}
