import Foundation
import SwiftUI

class MarkerOverlayExecutor: NSObject, SkillExecutor {
    @objc func execute(params: [String: Any]) async throws -> Any {
        print("MarkerOverlayExecutor \(params)")

        if let clear = params["clear"] as? Bool, clear {
            MarkerOverlayManager.shared.clear()
            return SkillResult(success: true, data: "Markers cleared")
        }

        if let rectDict = params["rect"] as? [String: Any],
           let x = rectDict["x"] as? CGFloat,
           let y = rectDict["y"] as? CGFloat,
           let w = rectDict["w"] as? CGFloat,
           let h = rectDict["h"] as? CGFloat {
            
            let color = parseColor(params["color"])
            let duration = params["duration"] as? TimeInterval
            MarkerOverlayManager.shared.drawRect(CGRect(x: x, y: y, width: w, height: h), color: color, duration: duration)
            return SkillResult(success: true, data: "Drew rectangle")
        }

        if let text = params["text"] as? String {
            let pointDict = params["point"] as? [String: Any]
            let x = pointDict?["x"] as? CGFloat ?? 0
            let y = pointDict?["y"] as? CGFloat ?? 0
            let color = parseColor(params["color"])
            let duration = params["duration"] as? TimeInterval
            MarkerOverlayManager.shared.drawText(text, at: CGPoint(x: x, y: y), color: color, duration: duration)
            return SkillResult(success: true, data: "Drew text")
        }

        if let pointDict = params["point"] as? [String: Any],
           let x = pointDict["x"] as? CGFloat,
           let y = pointDict["y"] as? CGFloat {
            
            let d = (params["duration"] as? TimeInterval) ?? (params["duration"] as? Double).map { TimeInterval($0) }
            MarkerOverlayManager.shared.moveCursor(to: CGPoint(x: x, y: y), duration: d)
            return SkillResult(success: true, data: "Moved cursor marker")
        }

        return SkillResult(success: false, error: "Invalid parameters for marker-overlay")
    }

    private func parseColor(_ colorStr: Any?) -> Color {
        guard let s = colorStr as? String else { return .red }
        switch s.lowercased().trimmingCharacters(in: .whitespaces) {
            case "red": return .red
            case "blue": return .blue
            case "green": return .green
            case "yellow": return .yellow
            case "white": return .white
            case "orange": return .orange
            default: return .red
        }
    }
}
