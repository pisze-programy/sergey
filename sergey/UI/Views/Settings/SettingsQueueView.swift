import SwiftUI

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
        SettingsPane("Queue") {
            HealthIndicator(healthService: healthService)
        } content: {
            VStack(spacing: 0) {
                statsBar
                Divider()
                taskArea
                footer
            }
        }
    }

    private var statsBar: some View {
        let s = queueManager.stats
        return HStack(spacing: 16) {
            statBox(count: s.totalCount, label: "Total", color: .primary)
            statBox(count: s.pendingCount, label: "Pending", color: .orange)
            statBox(count: s.runningCount, label: "Running", color: .green)
            statBox(count: s.completedCount, label: "Completed", color: .blue)
            statBox(count: s.failedCount, label: "Failed", color: .red)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var taskArea: some View {
        VStack(spacing: 12) {
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
            .padding(.horizontal, 24)
            .padding(.top, 12)

            if queueManager.tasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
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
                    .padding(24)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Retry Selected") {
                selectedTasks.forEach { queueManager.retryTask($0) }
                selectedTasks.removeAll()
            }
            .disabled(selectedTasks.isEmpty || queueManager.tasks.filter({ $0.status == .failed }).isEmpty)
            .buttonStyle(.plain)

            Spacer()

            Button("Clear Completed") {
                queueManager.purgeCompleted(days: 0)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button("Clear All") {
                queueManager.clearAll()
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(24)
    }

    private func statBox(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
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
