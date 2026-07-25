import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore = HistoryStore.shared

    var body: some View {
        NavigationSplitView {
            List(historyStore.data.sessions, selection: $selectedSessionID) { session in
                NavigationLink(value: session.id) {
                    VStack(alignment: .leading) {
                        Text(session.createdAt.formatted(.dateTime.month().day().hour().minute()))
                            .font(.subheadline)
                        Text("\(session.messages.count) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Sessions")
        } detail: {
            if let sessionID = selectedSessionID,
               let session = historyStore.data.sessions.first(where: { $0.id == sessionID }) {
                List(session.messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(message.role.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(message.role == "user" ? .blue : .green)
                            Spacer()
                            Text(message.timestamp.formatted(.dateTime.hour().minute().second()))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Text(message.content)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
                .navigationTitle("Details")
            } else {
                Text("Select a session")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 600, height: 500)
    }

    @State private var selectedSessionID: UUID?
}

#Preview {
    HistoryView()
}
