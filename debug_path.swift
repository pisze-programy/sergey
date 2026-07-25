import Foundation

let currentDir = FileManager.default.currentDirectoryPath
print("Current Directory: \(currentDir)")

let skillsBaseURL = URL(fileURLWithPath: currentDir).appendingPathComponent("sergey/Skills")
print("Looking for skills in: \(skillsBaseURL.path)")

let fileManager = FileManager.default
if fileManager.fileExists(atPath: skillsBaseURL.path) {
    print("Directory exists!")
    let enumerator = fileManager.enumerator(at: skillsBaseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
    while let fileURL = enumerator?.nextObject() as? URL {
        print("Found: \(fileURL.path)")
    }
} else {
    print("Directory does NOT exist!")
}
