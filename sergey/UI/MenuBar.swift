import SwiftUI
import AVFoundation
import Speech
import Combine

struct MenuBar: View {
    let onQuit: () -> Void

    @State private var micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    @State private var screenAuthorized = CGPreflightScreenCaptureAccess()
    @State private var ollamaAvailable = false
    private let ollamaClient = OllamaClient()
    private let timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                Text("Sergey AI")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
            
            Divider()
            
            Text("STATUS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)

            statusRow(title: "Microphone", isConnected: micAuthorized) {
                NSApp.activate(ignoringOtherApps: true)
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async { micAuthorized = granted }
                }
            }

            statusRow(title: "Speech Recognition", isConnected: speechAuthorized) {
                NSApp.activate(ignoringOtherApps: true)
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async { speechAuthorized = (status == .authorized) }
                }
            }

            statusRow(title: "Screen Recording", isConnected: screenAuthorized) {
                NSApp.activate(ignoringOtherApps: true)
                CGRequestScreenCaptureAccess()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    screenAuthorized = CGPreflightScreenCaptureAccess()
                }
            }

            statusRow(title: "Ollama Server", isConnected: ollamaAvailable, showGrant: false) {}

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("HOTKEY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Fn + Shift")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 6)

            Divider()

            Button(role: .destructive, action: onQuit) {
                Text("Quit Sergey")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
        }
        .padding(8)
        .frame(width: 500)
        .onReceive(timer) { _ in
            Task {
                let available = await ollamaClient.isAvailable()
                await MainActor.run { ollamaAvailable = available }
            }
        }
        .onAppear {
            micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
            screenAuthorized = CGPreflightScreenCaptureAccess()
            Task {
                let available = await ollamaClient.isAvailable()
                await MainActor.run { ollamaAvailable = available }
            }
        }
    }

    @ViewBuilder
    private func statusRow(title: String, isConnected: Bool, showGrant: Bool = true, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Circle()
                .foregroundColor(isConnected ? .green : .red)
                .frame(width: 8, height: 8)
                .fixedSize()
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            if !isConnected && showGrant {
                Button("Grant", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 6)
    }
}

#Preview {
    MenuBar(
        onQuit: {}
    )
}
