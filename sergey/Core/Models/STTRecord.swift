import Foundation

struct STTRecord: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let languageCode: String
    let duration: TimeInterval
    let inserted: Bool

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), languageCode: String, duration: TimeInterval, inserted: Bool) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.languageCode = languageCode
        self.duration = duration
        self.inserted = inserted
    }
}
