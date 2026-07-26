import SwiftUI

struct MarkerOverlayView: View {
    @ObservedObject var state: MarkerState

    var body: some View {
        Canvas { context, size in
            for element in state.elements {
                switch element {
                case .rect(_, let rect, let color, let lineWidth):
                    let path = Path(rect)
                    context.stroke(path, with: .color(color), lineWidth: lineWidth)
                    
                case .text(_, let text, let point, let color):
                    // Canvas `draw` for Text is a bit limited in terms of alignment. 
                    // We use it here for simplicity.
                    context.draw(Text(text).foregroundColor(color), at: point)
                    
                case .cursor(_, let point):
                    let size: CGFloat = 10
                    let path = Path { p in
                        p.move(to: CGPoint(x: point.x - size, y: point.y))
                        p.addLine(to: CGPoint(x: point.x + size, y: point.y))
                        p.move(to: CGPoint(x: point.x, y: point.y - size))
                        p.addLine(to: CGPoint(x: point.x, y: point.y + size))
                    }
                    context.stroke(path, with: .color(.red), lineWidth: 2)
                }
            }
        }
        .ignoresSafeArea()
    }
}
