import SwiftUI

struct StatusOverlayView: View {
    @EnvironmentObject var manager: StatusOverlayManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(manager.isActive ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .shadow(color: manager.isActive ? Color.green : Color.red, radius: 4)
                    
                    Spacer()
                    
                    ZStack {
                        Text(manager.statusMessage)
                            .id(manager.statusMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)))
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.statusMessage)
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.primary.opacity(0.6))
                        .font(.system(size: 14))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.isExpanded ? nil : manager.showExpansion()
                }
                .padding(.horizontal, 15)
                .frame(width: 350, height: 55, alignment: .center)
            }
            
            if manager.isExpanded {
                ListPlaceholderView()
                    .frame(maxHeight: 300)
                    .padding(.top, 15)
                    .padding(.bottom, 30)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.isExpanded)
    }
}

struct ListPlaceholderView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<5) { index in
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Agent \(index + 1)")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Status: Running")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .onTapGesture {
                        print("Clicked item \(index)")
                    }
                }
            }
            .padding(.horizontal, 15)
        }
        .scrollIndicators(.hidden)
        .clipped()
    }
}
