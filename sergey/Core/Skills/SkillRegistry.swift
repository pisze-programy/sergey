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
    public let executor: SkillExecutor?

    public func execute(parameters: [String: Any]) async throws -> Any {
        if let executor = executor {
            return try await executor.execute(params: parameters)
        }
        return SkillResult(success: false, error: "No executor registered for \(name)")
    }
}

public final class SkillRegistry {
    public static let shared = SkillRegistry()
    private(set) var skills: [String: SkillDescriptor] = [:]
    private let skillsBaseURL = Bundle.main.resourceURL?.appendingPathComponent("Skills") ?? URL(fileURLWithPath: "/")
    
    private init() {}

    public func setExecutor(for name: String, executor: SkillExecutor) {
        if let skill = skills[name] {
            let newDescriptor = SkillDescriptor(
                name: skill.name,
                metadata: skill.metadata,
                executorPath: skill.executorPath,
                skillMdPath: skill.skillMdPath,
                executor: executor
            )
            skills[name] = newDescriptor
        }
    }

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
        
        print("[Skills] Skills loaded from metadata: \(skills.keys.sorted())")
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
                        case "description": description = value
                        default: break 
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
                skillMdPath: url.path,
                executor: nil
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
		return skills.map { "\($0.key): \($0.value.metadata.description)" }.joined(separator: "\n")
	}
}
