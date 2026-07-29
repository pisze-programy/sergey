import SwiftUI

struct StatusOverlayHeaderViewView: View {
    let isActive: Bool
    let statusMessage: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
                .shadow(color: isActive ? Color.green : Color.red, radius: 4)

            Spacer()

            ZStack {
                Text(statusMessage)
                    .id(statusMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: statusMessage)
            .frame(maxWidth: .infinity)

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.primary.opacity(0.6))
                .font(.system(size: 14))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .padding(.horizontal, 15)
        .frame(width: 350, height: 55, alignment: .center)
    }
}
