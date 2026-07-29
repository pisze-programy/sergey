import Foundation
import Combine
import SwiftUI

@MainActor
final class AgentStatusService: ObservableObject {
    static let shared = AgentStatusService()

    @Published var activeAgents: [AgentModel] = [] {
        didSet {
            print("📊 [AgentService] activeAgents changed: \(activeAgents.count) agents")
            for a in activeAgents {
                print("   - \(a.name): \(a.state.title)")
            }
        }
    }
    @Published var statusMessage: String = "" {
        didSet {
            print("💬 [AgentService] statusMessage -> \(statusMessage)")
        }
    }

    private init() {
        print("🔒 [AgentService] singleton init")
    }

    // MARK: - Agent Lifecycle
    
    func addAgent(name: String, workDescription: String, state: AgentModel.StateFlag = .inactive) {
        print("➕ [AgentService] addAgent(\"\(name)\", \"\(workDescription)\", \(state.title))")
        let agent = AgentModel(name: name, workDescription: workDescription, state: state)
        activeAgents.append(agent)
        HistoryStore.shared.appendLog(AgentLog(statusTitle: state.title, workDescription: workDescription), forAgentNamed: name)
        print("✅ [AgentService] agent added, total: \(activeAgents.count)")
    }

    func removeAgent(id: UUID) {
        print("❌ [AgentService] removeAgent(\(id))")
        if let found = activeAgents.first(where: { $0.id == id }) {
            print("✅ [AgentService] removing agent: \(found.name)")
            HistoryStore.shared.appendLog(AgentLog(statusTitle: "Removed", workDescription: found.workDescription), forAgentNamed: found.name)
            activeAgents.removeAll { $0.id == id }
        } else {
            print("⚠️  [AgentService] agent NOT FOUND for removal: \(id)")
        }
    }

    func updateAgentState(for id: UUID, state: AgentModel.StateFlag? = nil, workDescription: String? = nil) {
        print("🔄 [AgentService] updateAgentState(\(id), state=\(state?.title ?? "nil"), desc=\(workDescription ?? "nil"))")
        if let index = activeAgents.firstIndex(where: { $0.id == id }) {
            var agent = activeAgents[index]
            if let state = state { agent.state = state }
            if let description = workDescription { agent.workDescription = description }
            activeAgents[index] = agent

            HistoryStore.shared.appendLog(
                AgentLog(statusTitle: agent.state.title, workDescription: agent.workDescription),
                forAgentNamed: agent.name
            )
            print("✅ [AgentService] agent updated")
        } else {
            print("⚠️  [AgentService] agent NOT FOUND for update: \(id)")
        }
    }
    
    func updateStatusMessage(_ text: String) {
        print("💬 [AgentService] updateStatusMessage(\"\(text)\")")
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            statusMessage = text
        }
    }
}
