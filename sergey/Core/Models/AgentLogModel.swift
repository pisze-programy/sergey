import Foundation

public struct AgentLog: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public var statusTitle: String
    public var workDescription: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), statusTitle: String, workDescription: String) {
        self.id = id
        self.timestamp = timestamp
        self.statusTitle = statusTitle
        self.workDescription = workDescription
    }
}

public struct HistoryRecordAgent: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public let taskId: UUID?
    public var firstLaunchDate: Date
    public var logs: [AgentLog]

    public init(id: UUID = UUID(), name: String, taskId: UUID? = nil, firstLaunchDate: Date = Date(), logs: [AgentLog] = []) {
        self.id = id
        self.name = name
        self.taskId = taskId
        self.firstLaunchDate = firstLaunchDate
        self.logs = logs
    }
}

public struct HistoryDataRoot: Codable {
    public var agents: [HistoryRecordAgent]
}
