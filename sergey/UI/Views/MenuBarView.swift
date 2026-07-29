import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings = SettingsStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                HistoryWindowManager.shared.show()
            }) {
                Label("Agent History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)

            Divider()

            Button(action: {
                SettingsWindowManager.shared.show()
            }) {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)

            Divider()

            Button(action: { settings.isFocusModeEnabled.toggle() }) {
                Label(
                    "Focus Mode",
                    systemImage: settings.isFocusModeEnabled ? "eye.slash.fill" : "eye.slash"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(settings.isFocusModeEnabled ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)

            Divider()

            Button(role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
        .padding(6)
        .frame(width: 200)
    }
}

#Preview {
    MenuBarView()
}
