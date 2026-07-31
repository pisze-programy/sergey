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

    func appendLog(_ log: AgentLog, forTaskId taskId: UUID, agentName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var data = self.data
            if let matchedIndex = data.agents.firstIndex(where: { $0.taskId == taskId }) {
                var matchedAgent = data.agents[matchedIndex]
                matchedAgent.logs.insert(log, at: 0)
                data.agents[matchedIndex] = matchedAgent
            } else {
                let newAgent = HistoryRecordAgent(name: agentName, taskId: taskId, logs: [log])
                data.agents.append(newAgent)
            }
            self.data = data
            self.save()
        }
    }

    func deleteAgent(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var data = self.data
            data.agents.removeAll(where: { $0.id == id })
            self.data = data
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.data = HistoryDataRoot(agents: [])
            self.save()
        }
    }
}
