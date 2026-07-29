import SwiftUI

struct StatusOverlayView: View {
    @EnvironmentObject var manager: StatusOverlayManager
    @FocusState private var isInputFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            StatusOverlayHeaderView(
                isActive: manager.isActive,
                statusMessage: manager.statusMessage,
                isExpanded: manager.isExpanded,
                onTap: {
                    manager.isExpanded ? manager.hideExpansion() : manager.showExpansion()
                }
            )

            if manager.isExpanded {
                VStack(spacing: 15) {
                    StatusOverlayInputField(
                        text: $manager.userInput,
                        isFocused: $isInputFieldFocused,
                        onSubmit: manager.submitInput
                    )

                    Divider()
                        .padding(.vertical, 5)
                        .opacity(0.3)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<5) { index in
                                AgentRowView(
                                    name: "Agent \(index + 1)",
                                    status: "Status: Running",
                                    isRunning: true,
                                    onTap: {
                                        print("Clicked agent \(index + 1)")
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(15)
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
        .onChange(of: manager.isExpanded) { expanded in
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isInputFieldFocused = true
                }
            } else {
                isInputFieldFocused = false
            }
        }
    }
}
