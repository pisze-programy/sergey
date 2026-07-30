import SwiftUI

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
