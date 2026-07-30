import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case history
    case agents
    case queue
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
            case .history: return "History"
            case .agents: return "Agents"
            case .queue: return "Queue"
            case .general: return "General"
        }
    }

    var icon: String {
        switch self {
            case .history: return "clock.arrow.circlepath"
            case .agents: return "person.2.fill"
            case .queue: return "list.bullet.rectangle"
            case .general: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()
                .padding(.vertical, 8)

            contentArea
                .frame(minWidth: 500, maxWidth: .infinity)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    sidebarButton(section: section)
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
    }

    @ViewBuilder
    private func sidebarButton(section: SettingsSection) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(8)
            .background(selectedSection == section ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .foregroundColor(selectedSection == section ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch selectedSection {
                case .history:
                    SettingsHistoryView()
                case .agents:
                    SettingsAgentsView()
                case .queue:
                    SettingsQueueView()
                case .general:
                    SettingsGeneralView()
            }
        }
        .transition(.opacity)
    }
}
