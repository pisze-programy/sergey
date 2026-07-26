import SwiftUI

enum MarkerElement: Identifiable {
    case rect(id: UUID, rect: CGRect, color: Color, lineWidth: CGFloat)
    case text(id: UUID, text: String, point: CGPoint, color: Color)
    case cursor(id: UUID, point: CGPoint)

    var id: UUID {
        switch self {
        case .rect(let id, _, _, _): return id
        case .text(let id, _, _, _): return id
        case .cursor(let id, _): return id
        }
    }
}
