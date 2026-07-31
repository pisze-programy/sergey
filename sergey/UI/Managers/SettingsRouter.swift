import Foundation
import Combine

/// Coordinates deep links from the overlay into the Settings window,
/// e.g. "open Settings → History → this agent" when the user clicks
/// the Current Task box in the agent detail panel.
@MainActor
final class SettingsRouter: ObservableObject {
    static let shared = SettingsRouter()

    @Published var requestedSection: SettingsSection?
    @Published var requestedAgentID: UUID?

    private init() {}

    func openHistory(for agentID: UUID) {
        requestedSection = .history
        requestedAgentID = agentID
        SettingsWindowManager.shared.show()
    }
}
