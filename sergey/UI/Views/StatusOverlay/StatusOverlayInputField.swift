import SwiftUI

struct StatusOverlayInputField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            TextField("Enter command...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused(isFocused)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}
