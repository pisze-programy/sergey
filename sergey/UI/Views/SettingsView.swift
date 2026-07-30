import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case stt
    case history
    case agents
    case queue

    var id: String { rawValue }

    var title: String {
        switch self {
            case .general: return "General"
            case .stt: return "Records"
            case .history: return "History"
            case .agents: return "Agents"
            case .queue: return "Queue"
        }
    }

    var icon: String {
        switch self {
            case .general: return "gearshape"
            case .stt: return "waveform"
            case .history: return "clock.arrow.circlepath"
            case .agents: return "person.2.fill"
            case .queue: return "list.bullet.rectangle"
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
            .frame(maxWidth: .infinity)
            .background(selectedSection == section ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .foregroundColor(selectedSection == section ? .accentColor : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }


    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch selectedSection {
                case .general:
                    SettingsGeneralView()
                case .stt:
                    SettingsSTTView()
                case .history:
                    SettingsHistoryView()
                case .agents:
                    SettingsAgentsView()
                case .queue:
                    SettingsQueueView()
            }
        }
        .transition(.opacity)
    }
}
