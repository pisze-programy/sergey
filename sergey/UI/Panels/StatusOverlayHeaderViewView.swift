import SwiftUI

struct StatusOverlayHeaderViewView: View {
    let isActive: Bool
    let statusMessage: String
    let isExpanded: Bool
    let onTap: () -> Void

    let targetAppIcon: NSImage?
    let targetAppName: String?
    let isDictationActive: Bool

    init(
        isActive: Bool,
        statusMessage: String,
        isExpanded: Bool,
        onTap: @escaping () -> Void,
        targetAppIcon: NSImage? = nil,
        targetAppName: String? = nil,
        isDictationActive: Bool = false
    ) {
        self.isActive = isActive
        self.statusMessage = statusMessage
        self.isExpanded = isExpanded
        self.onTap = onTap
        self.targetAppIcon = targetAppIcon
        self.targetAppName = targetAppName
        self.isDictationActive = isDictationActive
    }

    var body: some View {
        HStack(spacing: 0) {
            statusIndicator
                .layoutPriority(1)

            centerMessage
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 8)

            chevron
                .layoutPriority(1)
        }
        .animation(.easeInOut(duration: 0.25), value: statusMessage)
        .animation(.easeInOut(duration: 0.25), value: isDictationActive)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .padding(.horizontal, 16)
        .frame(width: 350, height: 55, alignment: .center)
    }

    private var centerMessage: some View {
        Text(statusMessage)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary.opacity(0.8))
            .lineLimit(1)
            .id(statusMessage)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isDictationActive, let icon = targetAppIcon {
            HStack(spacing: 5) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)

                if let name = targetAppName {
                    Text(name)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .help("Inserting into \(targetAppName ?? "active app")")
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .help(isActive ? "Ollama is reachable" : "Ollama is offline")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    private var chevron: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(.primary.opacity(0.5))
            .font(.system(size: 13, weight: .medium))
            .frame(width: 16)
    }
}
