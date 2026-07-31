import Foundation

final class ToolRegistry {
    static let shared = ToolRegistry()

    private(set) var tools: [String: AgentTool] = [:]

    private init() {
        register(ScreenCaptureTool())
        register(OpenURLTool())
        register(FrontmostAppTool())
        register(InsertTextTool())
        register(NotifyTool())
        register(BrowserTool())
    }

    func register(_ tool: AgentTool) {
        tools[tool.name] = tool
    }

    func tool(named name: String) -> AgentTool? {
        tools[name]
    }

    var toolDescriptions: String {
        tools.values
            .sorted { $0.name < $1.name }
            .map { "- \($0.name): \($0.description)" }
            .joined(separator: "\n")
    }
}
