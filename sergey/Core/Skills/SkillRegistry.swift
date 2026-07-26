import Foundation

public struct SkillMetadata {
    public let name: String
    public let description: String
    public let parameters: [String: String]
}

public struct SkillDescriptor {
    public let name: String
    public let metadata: SkillMetadata
    public let executorPath: String
    public let skillMdPath: String

    public func execute(parameters: [String: Any]) async throws -> Any {
        // Note: Implementation of actual execution logic goes here in a future phase.
        // For now, we return a placeholder to allow compilation.
        return "Simulated execution of \(name) with parameters: \(parameters)"
    }
}

public final class SkillRegistry {
    public static let shared = SkillRegistry()
    private(set) var skills: [String: SkillDescriptor] = [:]
    private let skillsBaseURL = Bundle.main.resourceURL?.appendingPathComponent("Skills") ?? URL(fileURLWithPath: "/")
    
    private init() {}

    public func loadAllSkills() {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: skillsBaseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            print("[Skills] Error: Could not create enumerator for \(skillsBaseURL.path)")
            return
        }

        for case let skillURL as URL in enumerator {
            if skillURL.pathExtension == "md" && skillURL.lastPathComponent == "SKILL.md" {
                do {
                    try registerSkill(at: skillURL)
                } catch {
                    print("[Skills] Failed to load skill at \(skillURL.path): \(error)")
                }
            }
        }
        
        print("[Skills] Skills loaded: \(skills.keys.sorted())")
    }

    private func registerSkill(at url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var name: String?
        var description: String?
        
        var inYaml = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                inYaml.toggle()
                continue
            }
            
            if inYaml {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    
                    switch key {
                        case "name": name = value
                        case 	"description": description = value
                        default: break // Expandable for param parsing
                    }
                }
            }
        }

        if let name = name, let description = description {
            let skillFolder = url.deletingLastPathComponent()
            let folderName = skillFolder.lastPathComponent
            let executorURL = skillFolder.appendingPathComponent("\(folderName).swift")

            guard FileManager.default.fileExists(atPath: executorURL.path) else {
                print("[Skills] Error: Executor not found at \(executorURL.path)")
                return
            }

            let descriptor = SkillDescriptor(
                name: name,
                metadata: SkillMetadata(name: name, description: description, parameters: [:]),
                executorPath: executorURL.path,
                skillMdPath: url.path
            )

            skills[name] = descriptor
        }
    }
    
    public func getSkill(name: String) -> SkillDescriptor? {
        return skills[name]
    }

    public var allSkillNames: [String] {
        return Array(skills.keys)
    }
	
	public var inventorySummary: String {
		return "Available Skills:\n" + skills.map { "\($0.key): \($0.value.metadata.description)" }.joined(separator: "\n")
	}
}
