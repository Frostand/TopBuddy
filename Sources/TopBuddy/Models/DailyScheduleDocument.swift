import Foundation

struct DailyScheduleDocument: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let date: String
    let refreshedAt: String
    let source: String
    let blocks: [ScheduleBlock]
    let rollover: [String]

    init(
        schemaVersion: Int = 2,
        date: String,
        refreshedAt: String,
        source: String,
        blocks: [ScheduleBlock],
        rollover: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.date = date
        self.refreshedAt = refreshedAt
        self.source = source
        self.blocks = blocks
        self.rollover = rollover
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case date
        case refreshedAt
        case source
        case blocks
        case rollover
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        date = try container.decode(String.self, forKey: .date)
        refreshedAt = try container.decodeIfPresent(String.self, forKey: .refreshedAt) ?? "Unknown"
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "Daily handoff"
        blocks = try container.decode([ScheduleBlock].self, forKey: .blocks)
        rollover = try container.decodeIfPresent([String].self, forKey: .rollover) ?? []
    }
}
