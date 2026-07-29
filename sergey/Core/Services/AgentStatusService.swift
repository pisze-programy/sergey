import Foundation
import Combine
import SwiftUI

@MainActor
final class AgentStatusService: ObservableObject {
    static let shared = AgentStatusService()

    @Published var activeAgents: [AgentModel] = []
    @Published var statusMessage: String = ""

    private init() {}
    
    func addAgent(name: String, workDescription: String, state: AgentModel.StateFlag = .inactive) {
        let agent = AgentModel(name: name, workDescription: workDescription, state: state)
        activeAgents.append(agent)
        HistoryStore.shared.appendLog(AgentLog(statusTitle: state.title, workDescription: workDescription), forAgentNamed: name)
    }

    func removeAgent(id: UUID) {
        if let found = activeAgents.first(where: { $0.id == id }) {
            HistoryStore.shared.appendLog(AgentLog(statusTitle: "Removed", workDescription: found.workDescription), forAgentNamed: found.name)
            activeAgents.removeAll { $0.id == id }
        }
    }

    func updateAgentState(for id: UUID, state: AgentModel.StateFlag? = nil, workDescription: String? = nil) {
        if let index = activeAgents.firstIndex(where: { $0.id == id }) {
            var agent = activeAgents[index]
            if let state = state { agent.state = state }
            if let description = workDescription { agent.workDescription = description }
            activeAgents[index] = agent

            HistoryStore.shared.appendLog(
                AgentLog(statusTitle: agent.state.title, workDescription: agent.workDescription),
                forAgentNamed: agent.name
            )
        }
    }
    
    func updateStatusMessage(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.statusMessage = text
        }
    }
}
