import SwiftUI

struct MenuBar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                HistoryWindowManager.shared.show()
            }) {
                Label("Session History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)

            Divider()

            Button(action: {
                SettingsWindowManager.shared.show()
            }) {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)

            Divider()

            Button(role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .frame(width: 180)
    }
}

#Preview {
    MenuBar()
}
