import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var historyStore = HistoryStore.shared
    @State private var selectedAgentID: UUID?
    @State private var paneWidth: CGFloat = 280

    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let maxLogsToShow = 20

    private var sortedAgents: [HistoryRecordAgent] {
        historyStore.data.agents.sorted(by: { $0.firstLaunchDate > $1.firstLaunchDate })
    }

    init() {
        self._selectedAgentID = State(initialValue: nil)

        self.dateFormatter = {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            return fmt
        }()
        self.timeFormatter = {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss"
            return fmt
        }()
    }

    private func ensureSelection() {
        if selectedAgentID == nil, !sortedAgents.isEmpty {
            selectedAgentID = sortedAgents[0].id
        }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                agentListPane
                    .frame(width: paneWidth)

                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 4)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newWidth = paneWidth + value.translation.width
                                paneWidth = max(200, min(600, newWidth))
                            }
                    )

                detailPane
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .onAppear(perform: ensureSelection)
    }

    private var agentListPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("Agent History")
                    .font(.headline)

                Spacer()

                if !historyStore.data.agents.isEmpty {
                    Button(role: .destructive) {
                        historyStore.clearAllHistory()
                    } label: {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red.opacity(0.85))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Divider()

            let isEmpty = sortedAgents.isEmpty
            if isEmpty {
                emptyPlaceholderView
            } else {
                List(sortedAgents, id: \.id, selection: $selectedAgentID) { agent in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(statusColor(for: agent.logs.last?.statusTitle ?? ""))
                            .frame(width: 7, height: 7)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(agent.name.capitalized)
                                .font(.system(size: 13).weight(.medium))

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
                    .contentShape(Rectangle())
                }
                .listStyle(.plain)
            }
        }
    }

    private var detailPane: some View {
        Group {
            if let id = selectedAgentID,
               let agent = sortedAgents.first(where: { $0.id == id }) {
                agentDetailView(for: agent)
            } else if !sortedAgents.isEmpty {
                let first = sortedAgents[0]
                agentDetailView(for: first)
                    .onAppear { selectedAgentID = first.id }
            } else {
                emptyDetailPlaceholder
            }
        }
    }

    private func agentDetailView(for agent: HistoryRecordAgent) -> some View {
        VStack(spacing: 0) {
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
                    historyStore.deleteAgent(id: agent.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(agent.logs.prefix(maxLogsToShow))) { log in
                        LogRowView(log: log, timeFormatter: timeFormatter)
                    }
                }
                .padding()
            }

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                Text("Total logs: \(agent.logs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if agent.logs.count > maxLogsToShow {
                    Text("Showing first \(maxLogsToShow)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    private var emptyPlaceholderView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No agents yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    private var emptyDetailPlaceholder: some View {
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

    private func statusColor(for title: String) -> Color {
        switch title.lowercased() {
            case "running": return .green
            case "stopped": return .orange
            case "inactive", "removed": return .gray
            default: return .secondary
        }
    }
}

private struct LogRowView: View {
    let log: AgentLog
    let timeString: String

    init(log: AgentLog, timeFormatter: DateFormatter) {
        self.log = log
        self.timeString = timeFormatter.string(from: log.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(log.statusTitle.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(statusColor)

                Spacer()

                Text(timeString)
                    .font(.system(size: 10).monospaced())
                    .foregroundColor(.secondary)
            }

            Text(log.workDescription)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color(nsColor: NSColor.controlBackgroundColor.withSystemEffect(.pressed)))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch log.statusTitle.lowercased() {
            case "running": return .green
            case "stopped": return .orange
            case "inactive", "removed": return .gray
            default: return .secondary
        }
    }
}

#Preview {
    HistoryView()
}
