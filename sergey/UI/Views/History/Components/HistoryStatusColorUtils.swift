import SwiftUI

enum HistoryStatusColor {
    static func color(for title: String) -> Color {
        switch title.lowercased() {
            case "running": return .green
            case "stopped": return .orange
            case "inactive", "removed": return .gray
            default: return .secondary
        }
    }
}
