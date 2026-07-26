import Foundation

final class PromptManager {
    static let shared = PromptManager()
    private init() {}

    func loadPrompt(name: String) -> String {
        let fileName = (name as NSString).deletingPathExtension
        let fileExt = (name as NSString).pathExtension
        let url = Bundle.main.url(forResource: fileName, withExtension: fileExt, subdirectory: "Prompts")!
        return try! String(contentsOf: url, encoding: .utf8)
    }
}
