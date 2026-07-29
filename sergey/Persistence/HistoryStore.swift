import Foundation
import Combine
import SwiftUI

class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    private let historyURL: URL

    @Published var data: HistoryDataRoot

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("sergey")
        self.historyURL = appFolder.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        if let rawData = try? Data(contentsOf: historyURL),
           let decoded = try? JSONDecoder().decode(HistoryDataRoot.self, from: rawData) {
            self.data = decoded
        } else {
            self.data = HistoryDataRoot(agents: [])
        }
    }

    func appendLog(_ log: AgentLog, forAgentNamed agentName: String) {
        DispatchQueue.main.async {
            if let matchedIndex = self.data.agents.firstIndex(where: { $0.name == agentName }) {
                var matchedAgent = self.data.agents[matchedIndex]
                matchedAgent.logs.insert(log, at: 0)
                self.data.agents[matchedIndex] = matchedAgent
            } else {
                let newAgent = HistoryRecordAgent(name: agentName, logs: [log])
                self.data.agents.append(newAgent)
            }
            self.save()
        }
    }

    func deleteAgent(id: UUID) {
        DispatchQueue.main.async {
            self.data.agents.removeAll(where: { $0.id == id })
            self.save()
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encoded = try encoder.encode(data)
            try encoded.write(to: historyURL)
        } catch { }
    }

    func clearAllHistory() {
        DispatchQueue.main.async {
            self.data = HistoryDataRoot(agents: [])
            self.save()
        }
    }
}
