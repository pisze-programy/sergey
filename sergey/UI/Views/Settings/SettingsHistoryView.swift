import SwiftUI

struct SettingsHistoryView: View {
    @ObservedObject var historyStore = HistoryStore.shared
    @State private var selectedAgentID: UUID?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private let maxLogsToShow = 50

    private var sortedAgents: [HistoryRecordAgent] {
        historyStore.data.agents.sorted(by: { $0.firstLaunchDate > $1.firstLaunchDate })
    }

    var body: some View {
        SettingsSplitPane {
            listSide
        } right: {
            detailSide
        }
    }

    private var listSide: some View {
        VStack(spacing: 0) {
            SettingsPageHeader("History") {
                if !sortedAgents.isEmpty {
                    Button(role: .destructive) {
                        historyStore.clearAllHistory()
                        selectedAgentID = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()

            if sortedAgents.isEmpty {
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
            } else {
                List(sortedAgents, id: \.id, selection: $selectedAgentID) { agent in
                    HistoryRowView(agent: agent, dateFormatter: dateFormatter)
                }
                .listStyle(.plain)
            }
        }
    }

    private var detailSide: some View {
        Group {
            if let id = selectedAgentID, let agent = sortedAgents.first(where: { $0.id == id }) {
                HistoryDetailContent(agent: agent, dateFormatter: dateFormatter, timeFormatter: timeFormatter, maxLogsToShow: maxLogsToShow)
            } else if let first = sortedAgents.first {
                HistoryDetailContent(agent: first, dateFormatter: dateFormatter, timeFormatter: timeFormatter, maxLogsToShow: maxLogsToShow)
                    .task { selectedAgentID = first.id }
            } else {
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
    }
}

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
                Text(dateFormatter.string(from: agent.firstLaunchDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(agent.logs.count)")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(nsColor: NSColor.controlBackgroundColor), in: Capsule())
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorForStatus(_ title: String) -> Color {
        switch title.lowercased() {
            case "running", "completed", "success": return .green
            case "stopped", "warning": return .orange
            case "error", "failed": return .red
            default: return .gray
        }
    }
}

struct HistoryDetailContent: View {
    let agent: HistoryRecordAgent
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter
    let maxLogsToShow: Int

    @State private var showDeleteAlert = false
    @ObservedObject private var historyStore = HistoryStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name.capitalized)
                        .font(.headline)
                    Text(dateFormatter.string(from: agent.firstLaunchDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    Alert(title: Text("Delete Agent History"),
                          message: Text("Remove all logs for \"\(agent.name)\"?"),
                          primaryButton: .destructive(Text("Delete")) { historyStore.deleteAgent(id: agent.id) },
                          secondaryButton: .cancel())
                }
            }
            .padding(24)

            Divider()

            if agent.logs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No logs for this agent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(agent.logs.prefix(maxLogsToShow).reversed())) { log in
                            HistoryLogRowView(log: log, timeFormatter: timeFormatter)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(24)
                }

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
                .padding(24)
            }
        }
    }
}
