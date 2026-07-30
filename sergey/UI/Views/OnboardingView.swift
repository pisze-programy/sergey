import SwiftUI


struct OnboardingView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var settings = SettingsStore.shared

    @State private var refreshTimer: Timer?
    @State private var dismissed = false

    private let requiredPermissions: [PermissionType] = [.microphone, .accessibility]
    private let optionalPermissions: [PermissionType] = [.notifications]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    requiredSection
                    optionalSection
                    footerSection
                }
                .padding(24)
            }
            Divider()
            bottomBar
        }
        .frame(width: 480)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            permissionManager.refresh()
            startRefreshing()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }


    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to Sergey")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Let's get you set up")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(24)
    }


    private var introSection: some View {
        Text("Sergey needs a few permissions to work properly. Please grant access below.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }


    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Required", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.orange)

            ForEach(requiredPermissions) { type in
                PermissionCardView(type: type, status: statusFor(type))
            }
        }
    }


    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Optional", systemImage: "star.fill")
                .font(.headline)
                .foregroundColor(.secondary)

            ForEach(optionalPermissions) { type in
                PermissionCardView(type: type, status: statusFor(type))
            }
        }
    }


    private var footerSection: some View {
        HStack {
            Image(systemName: permissionManager.allRequiredGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(permissionManager.allRequiredGranted ? .green : .orange)
            Text(permissionManager.allRequiredGranted
                 ? "All required permissions are granted."
                 : "Some required permissions are missing.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }


    private var bottomBar: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button("Continue") {
                markOnboardingComplete()
                closeWindow()
            }
            .buttonStyle(.borderedProminent)
            .disabled(false)
        }
        .padding(24)
    }


    private func statusFor(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:    return permissionManager.microphoneStatus
        case .accessibility: return permissionManager.accessibilityStatus
        case .notifications: return permissionManager.notificationStatus
        }
    }

    private func startRefreshing() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                permissionManager.refresh()
            }
        }
    }

    private func markOnboardingComplete() {
        settings.onboardingShown = true
    }

    private func closeWindow() {
        NSApplication.shared.windows
            .first(where: { $0.isVisible && $0.title == "Welcome to Sergey" })?
            .close()
    }
}


private struct PermissionCardView: View {
    let type: PermissionType
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(status.isGranted ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(type.title)
                        .font(.body.weight(.medium))
                    if !type.isRequired {
                        Text("Optional")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(NSColor.controlBackgroundColor), in: Capsule())
                    }
                }
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if status.isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                    .help("Granted")
            } else {
                Button("Open Settings") {
                    PermissionManager.shared.openSettings(for: type)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Open System Settings")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(status.isGranted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
