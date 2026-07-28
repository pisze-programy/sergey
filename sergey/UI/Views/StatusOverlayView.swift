import SwiftUI

struct StatusOverlayView: View {
    @EnvironmentObject var manager: StatusOverlayManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .shadow(color: .green, radius: 4)
                
                Text(manager.overlayText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.primary.opacity(0.6))
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 20)
        }
    }
}
