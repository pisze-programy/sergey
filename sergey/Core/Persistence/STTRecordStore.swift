import Foundation
import Combine
import OSLog

@MainActor
final class STTRecordStore: ObservableObject {
    static let shared = STTRecordStore()

    @Published var records: [STTRecord] = []

    private let log = Logger(subsystem: "sergey", category: "STTRecords")
    private let saveURL: URL
    private let maxRecords = 200

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        saveURL = home.appendingPathComponent(".sergey_stt_records.json")
        load()
    }

    func append(_ record: STTRecord) {
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        save()
    }

    func delete(_ ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        save()
    }

    func deleteAll() {
        records.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([STTRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(records) else {
            log.error("Failed to encode STT records")
            return
        }
        try? encoded.write(to: saveURL)
    }
}
