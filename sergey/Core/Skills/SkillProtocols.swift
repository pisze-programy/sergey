import Foundation

public protocol SkillExecutor {
    func execute(params: [String: Any]) async throws -> Any
}

public struct SkillResult {
    public let success: Bool
    public let data: Any?
    public let error: String?

    public init(success: Bool, data: Any? = nil, error: String? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}
