import Foundation

@MainActor
final class TaskDispatcher {
    static let shared = TaskDispatcher()
    
    private let queueManager = TaskQueueManager.shared
    private let healthService = OllamaHealthService.shared
    
    private var dispatchTimer: Timer?
    private let concurrentLimit = 4
    private let dispatchInterval: TimeInterval = 2
    
    private init() {}
    
    func start() {
        stop()
        
        healthService.startMonitoring(interval: 15)
        
        dispatchTimer = Timer.scheduledTimer(withTimeInterval: dispatchInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.dispatchCycle()
            }
        }
    }
    
    func stop() {
        dispatchTimer?.invalidate()
        dispatchTimer = nil
        healthService.stopMonitoring()
    }
    
    private func dispatchCycle() async {
        guard healthService.isHealthy else {
            CommunicationDispatcher.shared.updateStatusOnly("Ollama offline — queuing tasks")
            return
        }
        
        let activeRunningTasks = queueManager.tasks.filter { $0.status == .running }.count
        guard activeRunningTasks < concurrentLimit else { return }
        
        guard let nextTask = queueManager.dequeueNextReadyTask() else {
            return
        }
        
        agentExecutor.execute(task: nextTask)
    }
    
    private let agentExecutor = AgentExecutor()
}

final class AgentExecutor {
    private let llmService = LLMService.shared
    private let queueManager = TaskQueueManager.shared
    
    func execute(task: QueuedTask) {
        guard let executedTask = queueManager.markRunning(task.id) else { return }
        
        CommunicationDispatcher.shared.dispatch(
            message: "Started: \(executedTask.title)",
            priority: .normal
        )
        
        Task { @MainActor in
            await performExecution(of: executedTask.id)
        }
    }
    
    private func performExecution(of taskId: UUID) async {
        guard let task = queueManager.tasks.first(where: { $0.id == taskId }) else { return }
        
        do {
            _ = try await llmService.generateScopedResponse(
                systemPrompt: buildSystemPrompt(for: task),
                prompt: task.prompt
            )
            
            queueManager.markCompleted(taskId)
            CommunicationDispatcher.shared.dispatch(
                message: "Completed: \(task.title)",
                priority: .info
            )
        } catch {
            let reason = error.localizedDescription
            
            if let queued = queueManager.markFailed(taskId, reason: "Retry: \(reason)") {
                CommunicationDispatcher.shared.dispatch(
                    message: "Retrying (\(queued.retryCount)/\(queued.maxRetries)): \(task.title)",
                    priority: .warning
                )
            } else {
                CommunicationDispatcher.shared.dispatch(
                    message: "Failed (permanent): \(task.title) — \(reason)",
                    priority: .critical
                )
            }
        }
    }
    
    private func buildSystemPrompt(for task: QueuedTask) -> String {
        return """
        You are a focused assistant. Complete the following task precisely and concisely.
        Task: \(task.title)
        Priority: \(task.priority)
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
