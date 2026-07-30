import SwiftUI

struct SettingsGeneralView: View {
    @ObservedObject var store = SettingsStore.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var healthService = OllamaHealthService.shared

    var body: some View {
        SettingsPane("General") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PermissionStatusView()
                        .environmentObject(permissionManager)

                    SettingsSectionContainer("Ollama Connection", subtitle: "The endpoint where your local Ollama server is running.") {
                        OllamaHealthRow(healthService: healthService)
                        SettingsDivider()
                        SettingsTextFieldRow("Server URL", placeholder: "http://localhost:11434", text: $store.ollamaURL)
                        SettingsTextFieldRow("Default Model", subtitle: "The specific model to use for processing.", placeholder: "gemma4:26mu-a4b-it-q4_K_M", text: $store.modelName)
                    }

                    SettingsSectionContainer("Speech-to-Text", subtitle: "Offline voice dictation using Parakeet TDT v3.") {
                        SettingsToggleRow("Enable Dictation", isOn: $store.sttEnabled)
                        SettingsPickerRow(selection: $store.sttLanguageCode, disabled: !store.sttEnabled) {
                            Text("Language")
                        } content: {
                            Text("English").tag("en")
                            Text("Polski").tag("pl")
                        }
                        SettingsToggleRow("Auto-send to LLM on Transcribe Finish", isOn: $store.sttAutoSubmit, disabled: !store.sttEnabled)
                        SettingsToggleRow("Save Records", subtitle: "Keep a history of all dictations.", isOn: $store.sttSaveRecords, disabled: !store.sttEnabled)
                    }

                    SettingsSectionContainer("Focus Mode") {
                        SettingsToggleRow("Focus Mode", subtitle: "Suppress overlay updates. Only critical notifications are shown.", isOn: $store.isFocusModeEnabled)
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            permissionManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { @MainActor in
                await healthService.performHealthCheck()
            }
        }
    }
}


private struct OllamaHealthRow: View {
    @ObservedObject var healthService: OllamaHealthService
    @State private var isChecking = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(healthService.isHealthy ? Color.green : Color.red)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(healthService.isHealthy ? "Connected" : "Disconnected")
                    .font(.body.weight(.medium))
                    .foregroundColor(healthService.isHealthy ? .green : .red)
                if let lastCheck = healthService.lastCheckedAt {
                    Text("Last checked \(timeAgo(lastCheck))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !healthService.isHealthy {
                Button("Check Now") {
                    checkNow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isChecking)
            } else {
                Button("Check") {
                    checkNow()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                .disabled(isChecking)
            }
        }
        .padding(.vertical, 4)
    }

    private func checkNow() {
        guard !isChecking else { return }
        isChecking = true
        Task { @MainActor in
            await healthService.performHealthCheck()
            isChecking = false
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = abs(date.timeIntervalSinceNow)
        if interval < 10 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}


struct PermissionStatusView: View {
    @EnvironmentObject private var permissionManager: PermissionManager

    private let allTypes: [PermissionType] = PermissionType.allCases

    var body: some View {
        SettingsSectionContainer("Permissions", subtitle: "Required for Sergey to function properly.") {
            VStack(spacing: 6) {
                ForEach(allTypes) { type in
                    PermissionRow(type: type, status: statusFor(type))
                    if type != allTypes.last {
                        SettingsDivider()
                    }
                }
            }
        }
    }

    private func statusFor(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:    return permissionManager.microphoneStatus
        case .accessibility: return permissionManager.accessibilityStatus
        case .notifications: return permissionManager.notificationStatus
        }
    }
}


private struct PermissionRow: View {
    let type: PermissionType
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(type.title)
                        .font(.body)
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
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(status.label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !status.isGranted {
                    Button("Open Settings") {
                        PermissionManager.shared.openSettings(for: type)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Open System Settings")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var color: Color {
        status.isGranted ? .green : (type.isRequired ? .red : .orange)
    }
}
