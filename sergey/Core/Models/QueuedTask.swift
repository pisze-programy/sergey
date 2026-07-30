import Foundation

public enum TaskStatus: String, Codable {
    case pending
    case scheduled
    case running
    case completed
    case failed
    
    var title: String {
        switch self {
            case .pending: return "Pending"
            case .scheduled: return "Scheduled"
            case .running: return "Running"
            case .completed: return "Completed"
            case .failed: return "Failed"
        }
    }
}

public struct QueuedTask: Identifiable, Codable, Hashable {
    public let id: UUID
    public let title: String
    
    var status: TaskStatus
    let priority: Int
    
    let prompt: String
    let scheduledAt: Date
    let createdAt: Date
    
    var retryCount: Int
    let maxRetries: Int
    var failureReason: String?
    
    var assignedToAgentId: UUID?
    
    public init(
        id: UUID = UUID(),
        title: String,
        status: TaskStatus = .pending,
        priority: Int = 5,
        prompt: String,
        scheduledAt: Date = Date(),
        createdAt: Date = Date(),
        retryCount: Int = 0,
        maxRetries: Int = 3,
        assignedToAgentId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.prompt = prompt
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.assignedToAgentId = assignedToAgentId
    }
    
    public func canRetry() -> Bool {
        return retryCount < maxRetries
    }
    
    public static func == (lhs: QueuedTask, rhs: QueuedTask) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
