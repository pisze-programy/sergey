import Foundation

@MainActor
final class TaskDispatcher {
    static let shared = TaskDispatcher()
    
    private let queueManager = TaskQueueManager.shared
    private let healthService = OllamaHealthService.shared
    
    private var dispatchTimer: Timer?
    private let concurrentLimit = 4
    private let dispatchInterval: TimeInterval = 2
    private var lastCycleWasOffline = false
    
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
    
    /// Wakes the dispatcher immediately when a new task is enqueued, instead of
    /// waiting for the next polling cycle.
    func notifyEnqueued() {
        guard dispatchTimer != nil else { return }
        Task { @MainActor in
            await self.dispatchCycle()
        }
    }
    
    private func dispatchCycle() async {
        guard healthService.isHealthy else {
            // Only announce the offline state once per transition so a long
            // outage does not spam the ticker on every 2s poll.
            if !lastCycleWasOffline {
                lastCycleWasOffline = true
                CommunicationDispatcher.shared.updateStatusOnly("Ollama offline — queuing tasks")
            }
            return
        }
        lastCycleWasOffline = false
        
        let activeRunningTasks = queueManager.tasks.filter { $0.status == .running }.count
        guard activeRunningTasks < concurrentLimit else { return }
        
        guard let nextTask = queueManager.dequeueNextReadyTask() else {
            return
        }
        
        // Mark the task running before handing it off so dequeueNextReadyTask()
        // can never return the same task twice.
        queueManager.markRunning(nextTask.id)
        agentExecutor.execute(task: nextTask)
    }
    
    private let agentExecutor = AgentExecutor()
}

final class AgentExecutor {
    func execute(task: QueuedTask) {
        CommunicationDispatcher.shared.dispatch(message: "Started: \(task.title)", priority: .normal)
        Task { @MainActor in
            await TaskExecutor.shared.execute(task: task)
        }
    }
}
