import SwiftUI

struct MenuBar: View {
    let onQuit: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                // TODO: Open New Session
            }) {
                Label("New Session", systemImage: "plus.circle")
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

            Button(role: .destructive, action: onQuit) {
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
    MenuBar(
        onQuit: {},
        onSettings: {}
    )
}
