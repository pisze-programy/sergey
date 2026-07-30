import SwiftUI
import AppKit

struct HistoryAgentListView: View {
    let sortedAgents: [HistoryRecordAgent]
    var selectedAgentID: UUID?
    var onSelectionChange: (UUID?) -> Void
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if sortedAgents.isEmpty {
                emptyPlaceholderView
            } else {
                agentList
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.blue)
            Text("Agent History")
                .font(.headline)

            Spacer()

            if !sortedAgents.isEmpty {
                Button(role: .destructive) {
                    HistoryStore.shared.clearAllHistory()
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red.opacity(0.85))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var agentList: some View {
        List(sortedAgents, id: \.id, selection: Binding(
            get: { selectedAgentID },
            set: { onSelectionChange($0) }
        )) { agent in
            HStack(spacing: 10) {
                Circle()
                    .fill(HistoryStatusColor.color(for: agent.logs.last?.statusTitle ?? ""))
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
}
