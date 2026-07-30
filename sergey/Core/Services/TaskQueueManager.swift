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
        tasks.append(task)
        save()
    }
    
    func schedule(_ task: QueuedTask, at date: Date) {
        var scheduledTask = task
        scheduledTask.status = .scheduled
        tasks.append(scheduledTask)
        save()
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
        
        var task = tasks[index]
        task.status = .running
        if let agentId = agentId {
            task.assignedToAgentId = agentId
        }
        tasks[index] = task
        
        save()
        return task
    }
    
    func markCompleted(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[index]
        task.status = .completed
        tasks[index] = task
        
        save()
    }
    
    func markFailed(_ taskId: UUID, reason: String) -> QueuedTask? {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
        
        var task = tasks[index]
        task.failureReason = reason
        
        if task.canRetry() {
            task.retryCount += 1
            task.status = .pending
            tasks[index] = task
            save()
            return task
        } else {
            task.status = .failed
            tasks[index] = task
            save()
            return nil
        }
    }
    
    func retryTask(_ taskId: UUID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskId && ($0.status == .failed || $0.status == .pending) }) else { return false }
        
        var task = tasks[index]
        task.status = .pending
        task.failureReason = nil
        tasks[index] = task
        save()
        return true
    }
    
    
    func purgeCompleted(days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        tasks.removeAll { $0.status == .completed && $0.createdAt < cutoff }
        save()
    }
    
    func clearAll() {
        tasks.removeAll()
        save()
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
            self.tasks = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    private func save() {
        guard let encoded = try? JSONEncoder().encode(tasks) else { return }
        try? encoded.write(to: queueURL)
    }
}
