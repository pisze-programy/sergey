import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore = HistoryStore.shared
    @State private var selectedSessionID: UUID?

    var body: some View {
        NavigationSplitView {
            List(historyStore.data.sessions.sorted(by: { $0.createdAt > $1.createdAt }), selection: $selectedSessionID) { session in
                NavigationLink(value: session.id) {
                    VStack(alignment: .leading) {
                        Text(session.createdAt.formatted(.dateTime.month().day().hour().minute()))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("\(session.messages.count) messages")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .contextMenu {
                    Button("Use this session") {
                        historyStore.useSession(id: session.id)
                    }
                    Button("Delete Session") {
                        historyStore.deleteSession(id: session.id)
                    }.foregroundColor(.red)
                }
            }
            .navigationTitle("Sessions")
        } detail: {
            if let sessionID = selectedSessionID,
               let session = historyStore.data.sessions.first(where: { $0.id == sessionID }) {
                List(session.messages) { message in
                    Group {
                        if message.role == "system" {
                            Text(message.content)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 2)
                        } else {
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
                    }
                    .contextMenu {
                        Button("Copy Content") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(message.content, forType: .string)
                        }
                        Button("Delete Message") {
                            if let sessionID = selectedSessionID {
                                historyStore.deleteMessage(sessionID: sessionID, messageID: message.id)
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Details")
            } else {
                Text("Select a session")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    HistoryView()
}
