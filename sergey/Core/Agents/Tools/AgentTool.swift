import Foundation

protocol AgentTool {
    var name: String { get }
    var description: String { get }   // human-readable, used in LLM system prompt
    func execute(parameters: [String: Any]) async throws -> String  // returns observation text for the LLM
}
