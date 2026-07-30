import SwiftUI

struct SettingsSTTView: View {
    @StateObject private var store = STTRecordStore.shared
    @State private var showDeleteAll = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .abbreviated
        f.zeroFormattingBehavior = .dropLeading
        return f
    }()

    var body: some View {
        SettingsPane("Records") {
            if !store.records.isEmpty {
                Button(role: .destructive) {
                    showDeleteAll = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .alert("Delete all records?", isPresented: $showDeleteAll) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) { store.deleteAll() }
                } message: { Text("This cannot be undone.") }
            }
        } content: {
            VStack(spacing: 0) {
                Text("History of all speech-to-text dictations")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if store.records.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "waveform")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No STT Records")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Records will appear here after each dictation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    recordsList
                }
            }
        }
    }

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.records) { record in
                    recordCard(record)
                        .contextMenu {
                            Button("Copy Text") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.text, forType: .string)
                            }
                            Button("Copy with Timestamp") {
                                let content = "[\(dateFormatter.string(from: record.timestamp))] \(record.text)"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(content, forType: .string)
                            }
                            Divider()
                            Button(role: .destructive) {
                                store.delete([record.id])
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(24)
        }
    }

    private func recordCard(_ record: STTRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.text)
                .font(.system(size: 14))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Label(dateFormatter.string(from: record.timestamp), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if record.duration >= 1 {
                    Label(durationFormatter.string(from: record.duration) ?? "", systemImage: "stopwatch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: record.inserted ? "checkmark.circle.fill" : "clipboard.fill")
                        .font(.caption)
                    Text(record.inserted ? "Inserted" : "Copied")
                        .font(.caption)
                }
                .foregroundColor(record.inserted ? .green : .orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
