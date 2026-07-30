import Foundation
import SwiftUI

public struct AgentModel: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var workDescription: String
    public var state: StateFlag
    public var activeTaskId: UUID?
    
    public enum StateFlag: Int, CaseIterable, Codable {
        case running, stopped, inactive
        
        var color: Color { 
            switch self {
                case .running: return .green
                case .stopped: return .orange
                case .inactive: return .gray.opacity(0.6)
            }
        }

        var icon: String {
             switch self {
                case .running: return "play.fill"
                case .stopped: return "stop.fill"
                case .inactive: return "pause.fill"
            }
        }

        var title: String {
             switch self {
                case .running: return "Running"
                case .stopped: return "Stopped"
                case .inactive: return "Inactive"
            }
        }
    }

    public init(id: UUID = UUID(), name: String, workDescription: String, state: StateFlag) {
        self.id = id
        self.name = name
        self.workDescription = workDescription
        self.state = state
    }

    public static func == (lhs: AgentModel, rhs: AgentModel) -> Bool {
        return lhs.id == rhs.id
    }
}
