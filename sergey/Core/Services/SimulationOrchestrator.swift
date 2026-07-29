import Foundation

@MainActor
final class SimulationOrchestrator {
    private let agentService: AgentStatusService

    private let agentNames = ["Coder", "Researcher", "Designer", "QA", "Architect"]
    private let workTasks = [
        "Compiling main module...",
        "Scanning documentation...",
        "Generating UI mockups...",
        "Running unit tests...",
        "Optimizing database queries...",
        "Indexing file structure...",
        "Parsing network traffic...",
        "Analyzing git history..."
    ]
    
    private var step = 0
    
    init(_ service: AgentStatusService) {
        print("🤖 [SimOrch] init with agentService")
        self.agentService = service
    }

    func start() {
        print("▶️  [SimOrch] start() called")
        Task { @MainActor in
            print("▶️  [SimOrch] initial status update task running")
            agentService.updateStatusMessage("Initializing agents...")
        }

        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                print("🔄 [SimOrch] timer tick, step=\(self.step)")
                self.simulateAgentCycle()
            }
        }
    }
    
    // MARK: - Private Simulation Logic
    
    private let maxAgents: Int = 10
    private var testAgentIds: [UUID] = []

    private func simulateAgentCycle() {
        let phase = step % 5
        let atLimit = agentService.activeAgents.count >= maxAgents
        defer { step += 1 }

        print("🔢 [SimOrch] phase=\(phase), atLimit=\(atLimit), agents=\(agentService.activeAgents.count)")

        switch phase {
        case 0:
            guard !atLimit else { break }
            agentService.addAgent(name: "Coder", workDescription: "Initializing environment...", state: .running)
        case 1:
            guard !atLimit else { break }
            agentService.addAgent(name: "Researcher", workDescription: "Fetching external data...", state: .running)
        case 2:
            guard !atLimit else { break }
            agentService.addAgent(name: "Designer", workDescription: "Loading assets...", state: .running)
            if testAgentIds.count > 0 {
                agentService.updateAgentState(for: testAgentIds[0], state: nil, workDescription: "Coding core logic...")
            }
        case 3:
            agentService.activeAgents.enumerated().forEach { index, agent in
                let newState = index == 1 ? AgentModel.StateFlag.stopped : AgentModel.StateFlag.running
                let newDesc = self.workTasks.randomElement() ?? "Working..."
                agentService.updateAgentState(for: agent.id, state: newState, workDescription: newDesc)
            }
        case 4:
            if !testAgentIds.isEmpty {
                agentService.removeAgent(id: testAgentIds.first!)
            }
            guard !atLimit else { break }
            let name = self.agentNames.randomElement() ?? "Helper"
            let desc = self.workTasks.randomElement() ?? "Scanning..."
            agentService.addAgent(name: name, workDescription: desc, state: .inactive)
        default: break
        }

        testAgentIds = agentService.activeAgents.map(\.id)
    }
}
