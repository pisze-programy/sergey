import SwiftUI

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
                HistoryAgentListView(
                    sortedAgents: sortedAgents,
                    selectedAgentID: selectedAgentID,
                    onSelectionChange: { selectedAgentID = $0 },
                    dateFormatter: dateFormatter
                )
                .frame(width: paneWidth)

                resizableDivider

                detailPane
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .onAppear(perform: ensureSelection)
    }

    private var resizableDivider: some View {
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
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedAgentID,
           let agent = sortedAgents.first(where: { $0.id == id }) {
            HistoryAgentDetailView(
                agent: agent,
                dateFormatter: dateFormatter,
                timeFormatter: timeFormatter,
                maxLogsToShow: maxLogsToShow
            )
        } else if !sortedAgents.isEmpty {
            let first = sortedAgents[0]
            HistoryAgentDetailView(
                agent: first,
                dateFormatter: dateFormatter,
                timeFormatter: timeFormatter,
                maxLogsToShow: maxLogsToShow
            )
            .onAppear { selectedAgentID = first.id }
        } else {
            emptyDetailPlaceholder
        }
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
}

#Preview {
    HistoryView()
}
