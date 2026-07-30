import SwiftUI
import AppKit

struct HistoryLogRowView: View {
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
        HistoryStatusColor.color(for: log.statusTitle)
    }
}
