import SwiftUI

struct StatusOverlayView: View {
    @EnvironmentObject var manager: StatusOverlayManager
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 12) {
                Circle()
                    .fill(manager.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .shadow(color: manager.isActive ? Color.green : Color.red, radius: 4)
                
                Text(manager.overlayText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.primary.opacity(0.6))
                    .font(.system(size: 18))
                    .onTapGesture {
                        manager.handleMenuClick()
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .frame(maxWidth: 350, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.overlayText)
    }
}
