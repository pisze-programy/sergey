import Foundation
import Combine

struct HistoryMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

struct HistorySession: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    var messages: [HistoryMessage]

    init(id: UUID = UUID(), createdAt: Date = Date(), messages: [HistoryMessage] = []) {
        self.id = id
        self.createdAt = createdAt
        self.messages = messages
    }
}

struct HistoryData: Codable {
    var sessions: [HistorySession]
}

class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    private let historyURL: URL

    @Published var data: HistoryData

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("sergey")
        self.historyURL = appFolder.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: historyURL),
           let decoded = try? JSONDecoder().decode(HistoryData.self, from: data) {
            self.data = decoded
        } else {
            self.data = HistoryData(sessions: [])
        }
    }

    func appendMessage(_ message: HistoryMessage) {
        DispatchQueue.main.async {
            if var latestSession = self.data.sessions.last {
                latestSession.messages.append(message)
                self.data.sessions[self.data.sessions.count - 1] = latestSession
            } else {
                let newSession = HistorySession(messages: [message])
                self.data.sessions.append(newSession)
            }
            self.save()
        }
    }

    func startNewSession() {
        DispatchQueue.main.async {
            let newSession = HistorySession()
            self.data.sessions.append(newSession)
            self.save()
        }
    }

    func deleteSession(id: UUID) {
        DispatchQueue.main.async {
            self.data.sessions.removeAll(where: { $0.id == id })
            self.save()
        }
    }

    func deleteMessage(sessionID: UUID, messageID: UUID) {
        DispatchQueue.main.async {
            if let index = self.data.sessions.firstIndex(where: { $0.id == sessionID }) {
                self.data.sessions[index].messages.removeAll(where: { $0.id == messageID })
                // If session has no messages left, maybe we should delete the session too? 
                // The requirement didn't specify, but it's clean. 
                // However, user specifically asked for "delete element in session" and "delete whole session".
                // Let's keep empty sessions for now unless requested otherwise.
                self.save()
            }
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encoded = try encoder.encode(data)
            try encoded.write(to: historyURL)
        } catch {
            print("[HistoryStore] Failed to save history: \(error)")
        }
    }
}
