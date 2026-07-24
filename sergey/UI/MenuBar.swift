import SwiftUI
import AVFoundation
import Speech

struct MenuBar: View {
    let onQuit: () -> Void

    @State private var micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sergey AI")
                .font(.headline)
            Divider()
            
            Text("Permissions:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Circle()
                    .fill(micAuthorized ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("Microphone")
                Spacer()
                if !micAuthorized {
                    Button("Grant") {
                        NSApp.activate(ignoringOtherApps: true)
                        AVCaptureDevice.requestAccess(for: .audio) { granted in
                            DispatchQueue.main.async {
                                micAuthorized = granted
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack {
                Circle()
                    .fill(speechAuthorized ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("Speech Recognition")
                Spacer()
                if !speechAuthorized {
                    Button("Grant") {
                        NSApp.activate(ignoringOtherApps: true)
                        SFSpeechRecognizer.requestAuthorization { status in
                            DispatchQueue.main.async {
                                speechAuthorized = (status == .authorized)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()
            Text("Hotkeys:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("FN + SHIFT: Screenshot + Voice")
            Divider()

            Button("Quit") {
                onQuit()
            }
        }
        .padding(8)
        .frame(width: 240)
        .onAppear {
            micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        }
    }
}

#Preview {
    MenuBar(
        onQuit: {}
    )
}
