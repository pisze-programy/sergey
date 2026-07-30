import SwiftUI
import Foundation

struct SettingsQueueView: View {
    @StateObject private var queueManager = TaskQueueManager.shared
    @ObservedObject private var healthService = OllamaHealthService.shared
    
    @State private var newTaskTitle: String = ""
    @State private var newTaskPrompt: String = ""
    @State private var selectedTasks: Set<UUID> = []
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: .infinity))
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            statsHeader
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("Task title", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: enqueueTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(newTaskTitle.isEmpty)
                .buttonStyle(.plain)
            }
            
            Divider()
            
            taskList
            
            HStack {
                Button("Retry Selected") {
                    selectedTasks.forEach { queueManager.retryTask($0) }
                    selectedTasks.removeAll()
                }
                .disabled(selectedTasks.isEmpty || queueManager.tasks.filter({ $0.status == .failed }).isEmpty)
                
                Spacer()
                
                Button("Clear Completed") {
                    queueManager.purgeCompleted(days: 0)
                }
                .foregroundColor(.secondary)
                
                Button("Clear All") {
                    queueManager.clearAll()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private var statsHeader: some View {
        let s = queueManager.stats
        
        return HStack(spacing: 24) {
            statBox(count: s.totalCount, label: "Total", color: .primary)
            statBox(count: s.pendingCount, label: "Pending", color: .orange)
            statBox(count: s.runningCount, label: "Running", color: .green)
            statBox(count: s.completedCount, label: "Completed", color: .blue)
            statBox(count: s.failedCount, label: "Failed", color: .red)
            
            Spacer()
            
            HealthIndicator(healthService: healthService)
        }
    }
    
    @ViewBuilder
    private func statBox(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
    }
    
    private var taskList: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(queueManager.tasks) { task in
                    TaskRow(task: task, isSelected: selectedTasks.contains(task.id))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                if selectedTasks.contains(task.id) {
                                    selectedTasks.remove(task.id)
                                } else {
                                    selectedTasks.insert(task.id)
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func enqueueTask() {
        let task = QueuedTask(
            title: newTaskTitle,
            prompt: newTaskPrompt.isEmpty ? "Complete task: \(newTaskTitle)" : newTaskPrompt
        )
        queueManager.enqueue(task)
        newTaskTitle = ""
        newTaskPrompt = ""
    }
}

struct TaskRow: View {
    let task: QueuedTask
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(task.status.title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if task.retryCount > 0 {
                        Text("Retry: \(task.retryCount)/\(task.maxRetries)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if let reason = task.failureReason, !reason.isEmpty {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Text(task.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.5))
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var statusIcon: some View {
        Image(systemName: iconFor(task.status))
            .foregroundColor(colorFor(task.status))
            .frame(width: 20)
    }
    
    private func iconFor(_ status: TaskStatus) -> String {
        switch status {
            case .pending: return "clock"
            case .scheduled: return "calendar.badge.clock"
            case .running: return "play.fill"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark circle.fill"
        }
    }
    
    private func colorFor(_ status: TaskStatus) -> Color {
        switch status {
            case .pending: return .orange
            case .scheduled: return .blue
            case .running: return .green
            case .completed: return .gray
            case .failed: return .red
        }
    }
}

struct HealthIndicator: View {
    @ObservedObject var healthService: OllamaHealthService
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(healthService.isHealthy ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(healthService.isHealthy ? "Ollama Online" : "Ollama Offline")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let last = healthService.lastCheckedAt {
                Text("(\(last.formatted(date: .omitted, time: .shortened)))")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.5))
            }
        }
    }
}

struct SettingsHistoryView: View {
    @ObservedObject var historyStore = HistoryStore.shared
    @State private var selectedAgentID: UUID?

    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let maxLogsToShow = 50

    private var sortedAgents: [HistoryRecordAgent] {
        historyStore.data.agents.sorted(by: { $0.firstLaunchDate > $1.firstLaunchDate })
    }

    init() {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        self.dateFormatter = df

        let tf = DateFormatter()
        tf.dateFormat = "HH:mm:ss"
        self.timeFormatter = tf
    }

    var body: some View {
        HStack(spacing: 0) {
            historyList
                .frame(width: 320)

            Divider()
                .padding(.vertical, 8)

            detailArea
                .frame(minWidth: 400, maxWidth: .infinity)
        }
    }

    private var historyList: some View {
        VStack(spacing: 0) {
            historyHeader
            Divider()

            if sortedAgents.isEmpty {
                emptyPlaceholder
            } else {
                List(sortedAgents, id: \.id, selection: $selectedAgentID) { agent in
                    HistoryRowView(
                        agent: agent,
                        dateFormatter: dateFormatter
                    )
                }
                .listStyle(.plain)
            }
        }
    }

    private var historyHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.blue)
            Text("History")
                .font(.headline)

            Spacer()

            if !sortedAgents.isEmpty {
                Button(role: .destructive) {
                    historyStore.clearAllHistory()
                    selectedAgentID = nil
                } label: {
                    Image(systemName: "trash.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No history yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    private var detailArea: some View {
        Group {
            if let id = selectedAgentID,
               let agent = sortedAgents.first(where: { $0.id == id }) {
                HistoryDetailContent(
                    agent: agent,
                    dateFormatter: dateFormatter,
                    timeFormatter: timeFormatter,
                    maxLogsToShow: maxLogsToShow
                )
            } else if let first = sortedAgents.first {
                HistoryDetailContent(
                    agent: first,
                    dateFormatter: dateFormatter,
                    timeFormatter: timeFormatter,
                    maxLogsToShow: maxLogsToShow
                )
                .task { selectedAgentID = first.id }
            } else {
                detailEmptyState
            }
        }
    }

    private var detailEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Select an agent to view logs")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Row

struct HistoryRowView: View {
    let agent: HistoryRecordAgent
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(colorForStatus(agent.logs.last?.statusTitle ?? ""))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(agent.name.capitalized)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: agent.firstLaunchDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(agent.logs.count)")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(nsColor: NSColor.controlBackgroundColor), in: Capsule())
        }
    }

    private func colorForStatus(_ title: String) -> Color {
        switch title.lowercased() {
            case "running", "completed", "success":
                return .green
            case "stopped", "warning":
                return .orange
            case "error", "failed":
                return .red
            default:
                return .gray
        }
    }
}

// MARK: - Detail Content

struct HistoryDetailContent: View {
    let agent: HistoryRecordAgent
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter
    let maxLogsToShow: Int

    @State private var showDeleteAlert = false
    @ObservedObject private var historyStore = HistoryStore.shared

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()
            logList
            detailFooter
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name.capitalized)
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(dateFormatter.string(from: agent.firstLaunchDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Agent History"),
                    message: Text("Remove all logs for \"\(agent.name)\"?"),
                    primaryButton: .destructive(Text("Delete")) {
                        historyStore.deleteAgent(id: agent.id)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .padding()
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(agent.logs.prefix(maxLogsToShow).reversed())) { log in
                    HistoryLogRowView(log: log, timeFormatter: timeFormatter)
                }
            }
            .padding()
        }
    }

    private var detailFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.caption2)
            Text("Total logs: \(agent.logs.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if agent.logs.count > maxLogsToShow {
                Text("Showing last \(maxLogsToShow)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
