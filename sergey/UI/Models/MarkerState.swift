import SwiftUI
import Combine

@MainActor
class MarkerState: ObservableObject {
    @Published var elements: [MarkerElement] = []

    func add(_ element: MarkerElement) {
        elements.append(emptyIdElement(element))
    }

    private func emptyIdElement(_ element: MarkerElement) -> MarkerElement {
        // Note: In a real app, we might want to pass the ID from outside 
        // but for simplicity during development/testing we can wrap it
        return element 
    }

    func clear() {
        elements.removeAll()
    }

    func remove(id: UUID) {
        elements.removeAll { $0.id == id }
    }
}

// Helper to facilitate adding elements without manual UUID creation every time if we wanted,
// but for now let's keep it simple and just use the enum as is.
