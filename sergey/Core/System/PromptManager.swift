import Foundation

final class PromptManager {
    static let shared = PromptManager()
    private init() {}

    public func loadPrompt(name: String) -> String {
        let url = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Prompts")!
        return try! String(contentsOf: url, encoding: .utf8)
    }
}
