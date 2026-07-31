import Foundation
import Combine
import SwiftUI

@MainActor
final class AgentStatusService: ObservableObject {
    static let shared = AgentStatusService()

    @Published var activeAgents: [AgentModel] = []
    @Published var statusMessage: String = ""

    private init() {}
    
    func createAgent(name: String, workDescription: String, state: AgentModel.StateFlag = .inactive, taskId: UUID) -> UUID {
        var agent = AgentModel(name: name, workDescription: workDescription, state: state)
        agent.activeTaskId = taskId
        activeAgents.append(agent)
        HistoryStore.shared.appendLog(makeLog(statusTitle: state.title, workDescription: workDescription), forTaskId: taskId, agentName: name)
        return agent.id
    }

    func removeAgent(id: UUID) {
        activeAgents.removeAll { $0.id == id }
    }

    /// Updates the agent row without writing to history (used for per-turn streaming text).
    func updateAgentUI(for id: UUID, workDescription: String) {
        if let index = activeAgents.firstIndex(where: { $0.id == id }) {
            var agent = activeAgents[index]
            agent.workDescription = workDescription
            var copy = activeAgents
            copy[index] = agent
            activeAgents = copy
        }
    }

    func updateAgentState(for id: UUID, state: AgentModel.StateFlag? = nil, workDescription: String? = nil) {
        if let index = activeAgents.firstIndex(where: { $0.id == id }) {
            var agent = activeAgents[index]
            if let state = state { agent.state = state }
            if let description = workDescription { agent.workDescription = description }
            var copy = activeAgents
            copy[index] = agent
            activeAgents = copy

            HistoryStore.shared.appendLog(
                makeLog(statusTitle: agent.state.title, workDescription: agent.workDescription),
                forTaskId: agent.activeTaskId ?? agent.id,
                agentName: agent.name
            )
        }
    }

    private func makeLog(statusTitle: String, workDescription: String) -> AgentLog {
        // History stores the full text — logs are already meaningful events
        // (start, tool use, final answer, retries), not raw LLM monologues.
        AgentLog(statusTitle: statusTitle, workDescription: workDescription)
    }
    
    func updateStatusMessage(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.statusMessage = text
        }
    }
}

