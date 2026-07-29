import SwiftUI

struct AgentRowView: View {
    let name: String
    let status: String
    let isRunning: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                Text(status)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(isRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
