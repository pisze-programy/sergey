import Foundation

public struct AgentDefinitionModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var description: String
    public var systemPrompt: String
    public var modelName: String

    public init(id: UUID = UUID(), name: String, description: String, systemPrompt: String, modelName: String) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.modelName = modelName
    }
}
