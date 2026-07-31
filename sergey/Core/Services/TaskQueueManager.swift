import Foundation
import Combine
import SwiftUI

struct QueueStats {
    let totalCount: Int
    let pendingCount: Int
    let runningCount: Int
    let completedCount: Int
    let failedCount: Int
}

@MainActor
final class TaskQueueManager: ObservableObject {
    static let shared = TaskQueueManager()
    
    private let queueURL: URL
    
    @Published var tasks: [QueuedTask] = []
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("sergey")
        self.queueURL = appFolder.appendingPathComponent("task_queue.json")
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        load()
    }
    
    
    func enqueue(_ task: QueuedTask) {
        mutateTasks { $0.append(task) }
    }
    
    func schedule(_ task: QueuedTask, at date: Date) {
        var scheduledTask = task
        scheduledTask.status = .scheduled
        mutateTasks { $0.append(scheduledTask) }
    }
    
    
    func dequeueNextReadyTask() -> QueuedTask? {
        let now = Date()

        return tasks.filter { task in
            (task.status == .pending || task.status == .scheduled) && task.scheduledAt <= now
        }.sorted { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority > task2.priority
            }
            return task1.createdAt < task2.createdAt
        }.first
    }
    
    
    func markRunning(_ taskId: UUID, assignedToAgent agentId: UUID? = nil) -> QueuedTask? {
        guard let index = tasks.firstIndex(where: { $0.id == taskId && ($0.status == .pending || $0.status == .scheduled) }) else { return nil }
        var result: QueuedTask?
        mutateTasks { list in
            var task = list[index]
            task.status = .running
            if let agentId { task.assignedToAgentId = agentId }
            list[index] = task
            result = task
        }
        return result
    }
    
    func assignAgent(_ taskId: UUID, to agentId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        mutateTasks { list in
            list[index].assignedToAgentId = agentId
        }
    }
    
    func markCompleted(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        mutateTasks { list in
            list[index].status = .completed
        }
    }
    
    func markFailed(_ taskId: UUID, reason: String) -> QueuedTask? {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
        
        var result: QueuedTask?
        mutateTasks { list in
            var task = list[index]
            task.failureReason = reason
            
            if task.canRetry() {
                task.retryCount += 1
                task.status = .pending
                list[index] = task
                result = task
            } else {
                task.status = .failed
                list[index] = task
            }
        }
        return result
    }
    
    func retryTask(_ taskId: UUID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskId && ($0.status == .failed || $0.status == .pending) }) else { return false }
        mutateTasks { list in
            list[index].status = .pending
            list[index].failureReason = nil
        }
        return true
    }
    
    
    func purgeCompleted(days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        mutateTasks { list in
            list.removeAll { $0.status == .completed && $0.createdAt < cutoff }
        }
    }
    
    func clearAll() {
        mutateTasks { $0.removeAll() }
    }
    
    
    var stats: QueueStats {
        QueueStats(
            totalCount: tasks.count,
            pendingCount: tasks.filter { $0.status == .pending || $0.status == .scheduled }.count,
            runningCount: tasks.filter { $0.status == .running }.count,
            completedCount: tasks.filter { $0.status == .completed }.count,
            failedCount: tasks.filter { $0.status == .failed }.count
        )
    }
    
    
    private func load() {
        if let data = try? Data(contentsOf: queueURL),
           let decoded = try? JSONDecoder().decode([QueuedTask].self, from: data) {
            // Tasks persisted with status .running (e.g. the app was quit mid-task)
            // would be restored as .running, count against the concurrency limit,
            // and never be re-dispatched (dequeueNextReadyTask only returns
            // .pending/.scheduled). Normalize them to .pending so they re-run.
            self.tasks = decoded.map { task in
                var task = task
                if task.status == .running { task.status = .pending }
                return task
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    /// Mutates `tasks` through a full-array reassignment so `@Published`
    /// always fires, then persists the result.
    private func mutateTasks(_ transform: (inout [QueuedTask]) -> Void) {
        var copy = tasks
        transform(&copy)
        tasks = copy
        save()
    }
    
    private func save() {
        guard let encoded = try? JSONEncoder().encode(tasks) else { return }
        try? encoded.write(to: queueURL)
    }
}
