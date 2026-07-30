import SwiftUI

struct MenuBarView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                dismiss()
                SettingsWindowManager.shared.show()
            }) {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 180)
    }
}
