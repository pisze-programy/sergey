import SwiftUI

struct SelectionOverlay: View {
    var onSelection: (CGRect) -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(0.25)
                    .ignoresSafeArea()

                if let rect = selectionRect {
                    Rectangle()
                        .stroke(.blue, lineWidth: 2)
                        .background(
                            Rectangle()
                                .fill(.blue.opacity(0.15))
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(
                            x: rect.midX,
                            y: rect.midY
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startPoint == nil {
                            startPoint = value.startLocation
                        }

                        currentPoint = value.location
                    }
                    .onEnded { _ in
                        if let rect = selectionRect {
                            onSelection(rect)
                        }

                        startPoint = nil
                        currentPoint = nil
                    }
            )
        }
    }

    private var selectionRect: CGRect? {
        guard
            let start = startPoint,
            let end = currentPoint
        else {
            return nil
        }

        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

#Preview {
    SelectionOverlay { rect in
        print(rect)
    }
}