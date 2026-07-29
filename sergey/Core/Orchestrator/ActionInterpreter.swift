import Foundation

enum ActionInterpretationResult {
    case noAction
    case actionFound(skillName: String, parameters: [String: Any])
}

final class ActionInterpreter {
    static let shared = ActionInterpreter()
    private init() {}

    func cleanTextForDisplay(_ text: String) -> String {
        var cleaned = text
        if let thoughtRange = cleaned.range(of: "Thought:", options: .caseInsensitive) {
            cleaned.removeSubrange(..<thoughtRange.upperBound)
        }
        if let actionRange = cleaned.range(of: "Action:", options: .caseInsensitive) {
            cleaned.removeSubrange(actionRange.lowerBound..<cleaned.endIndex)
        }
        if let finalAnswerRange = cleaned.range(of: "Final Answer:", options: .caseInsensitive) {
            cleaned.removeSubrange(finalAnswerRange.lowerBound..<finalAnswerRange.upperBound)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func interpretAction(from response: String) -> ActionInterpretationResult {
        guard let actionRange = response.range(of: "Action:", options: .caseInsensitive) else {
            return .noAction
        }
        
        let instructionPart = String(response[actionRange.upperBound...])
        
        guard let openParenIdx = instructionPart.firstIndex(of: "("),
              let closeParenIdx = instructionPart.firstIndex(of: ")"),
              openParenIdx < closeParenIdx else {
            let skillName = instructionPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return .actionFound(skillName: skillName, parameters: [:])
        }

        let skillName = String(instructionPart[..<openParenIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let paramsString = String(instructionPart[instructionPart.index(after: openParenIdx)..<closeParenIdx])
        let parameters = parseParameters(paramsString)
        
        return .actionFound(skillName: skillName, parameters: parameters)
    }

    private func parseParameters(_ paramsString: String) -> [String: Any] {
        var dict: [String: Any] = [:]
        let pattern = ",(?![^\\[]*\\])(?![^{]*\\})"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(paramsString.startIndex..<paramsString.endIndex, in: paramsString)
        let components = regex?.matches(in: paramsString, options: [], range: range).map {
            String(paramsString[Range($0.range, in: paramsString)!])
        } ?? [paramsString]

        let parts = components.isEmpty ? paramsString.components(separatedBy: ",") : components
        
        for pair in parts {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                let key = kv[0].trimmingCharacters(in: .whitespaces)
                var val = kv[1].trimmingCharacters(in: .whitespaces)
                if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                    val = String(val.dropFirst().dropLast())
                }
                dict[key] = val
            }
        }
        return dict
    }
}
