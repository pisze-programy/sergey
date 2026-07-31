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

        guard let openParenIdx = instructionPart.firstIndex(of: "(") else {
            let skillName = instructionPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return .actionFound(skillName: skillName, parameters: [:])
        }

        // Find the matching closing paren, ignoring ")" inside quoted strings
        // or inside [] / {} brackets: e.g. insert_text(text="hello (world)").
        var quote: Character?
        var bracketDepth = 0
        var closeParenIdx: String.Index?
        var idx = instructionPart.index(after: openParenIdx)
        while idx < instructionPart.endIndex {
            let char = instructionPart[idx]
            if let activeQuote = quote {
                if char == "\\" {
                    let nextIdx = instructionPart.index(after: idx)
                    if nextIdx < instructionPart.endIndex, instructionPart[nextIdx] == activeQuote {
                        // Escaped quote: skip it, stay inside the quoted span.
                        idx = instructionPart.index(after: nextIdx)
                        continue
                    }
                } else if char == activeQuote {
                    quote = nil
                }
            } else if char == "\"" || char == "'" {
                quote = char
            } else if char == "[" || char == "{" {
                bracketDepth += 1
            } else if char == "]" || char == "}" {
                bracketDepth = max(0, bracketDepth - 1)
            } else if char == ")" && bracketDepth == 0 {
                closeParenIdx = idx
                break
            }
            idx = instructionPart.index(after: idx)
        }

        guard let closeIdx = closeParenIdx else {
            let skillName = instructionPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return .actionFound(skillName: skillName, parameters: [:])
        }

        let skillName = String(instructionPart[..<openParenIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let paramsString = String(instructionPart[instructionPart.index(after: openParenIdx)..<closeIdx])
        let parameters = parseParameters(paramsString)

        return .actionFound(skillName: skillName, parameters: parameters)
    }

    private func parseParameters(_ paramsString: String) -> [String: Any] {
        var parts: [String] = []
        var current = ""
        var quote: Character?
        var bracketDepth = 0
        var idx = paramsString.startIndex

        // Split on commas that are outside quoted values and outside [] / {} brackets.
        // Backslash-escaped quotes inside a quoted span (e.g. \") stay inside it and
        // have the backslash stripped from the extracted value.
        while idx < paramsString.endIndex {
            let char = paramsString[idx]
            if let activeQuote = quote {
                if char == "\\" {
                    let nextIdx = paramsString.index(after: idx)
                    if nextIdx < paramsString.endIndex, paramsString[nextIdx] == activeQuote {
                        current.append(activeQuote)
                        idx = paramsString.index(after: nextIdx)
                        continue
                    }
                }
                if char == activeQuote {
                    quote = nil
                }
                current.append(char)
            } else if char == "\"" || char == "'" {
                quote = char
                current.append(char)
            } else if char == "[" || char == "{" {
                bracketDepth += 1
                current.append(char)
            } else if char == "]" || char == "}" {
                bracketDepth = max(0, bracketDepth - 1)
                current.append(char)
            } else if char == "," && bracketDepth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(char)
            }
            idx = paramsString.index(after: idx)
        }
        parts.append(current)

        var dict: [String: Any] = [:]
        for pair in parts {
            guard let eqIndex = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            var val = String(pair[pair.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                val = String(val.dropFirst().dropLast())
            }
            guard !key.isEmpty else { continue }
            dict[key] = val
        }
        return dict
    }
}
