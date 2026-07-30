import SwiftUI

struct HistoryAgentDetailView: View {
    let agent: HistoryRecordAgent
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter
    let maxLogsToShow: Int

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            logsScrollView
            footerView
        }
    }

    private var headerView: some View {
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
                HistoryStore.shared.deleteAgent(id: agent.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var logsScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(agent.logs.prefix(maxLogsToShow))) { log in
                    HistoryLogRowView(log: log, timeFormatter: timeFormatter)
                }
            }
            .padding()
        }
    }

    private var footerView: some View {
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
