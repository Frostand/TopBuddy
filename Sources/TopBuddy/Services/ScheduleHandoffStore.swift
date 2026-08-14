import Foundation

@MainActor
final class ScheduleHandoffStore {
    let directoryURL: URL
    let handoffURL: URL

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        let base = directoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TopBuddy", isDirectory: true)
        self.directoryURL = base
        self.handoffURL = base.appendingPathComponent("today.json")
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: base.path)
    }

    func load(for date: Date, calendar: Calendar = .autoupdatingCurrent) throws -> DailyScheduleDocument? {
        guard FileManager.default.fileExists(atPath: handoffURL.path) else { return nil }
        let data = try Data(contentsOf: handoffURL)
        let document = try JSONDecoder().decode(DailyScheduleDocument.self, from: data)
        let expectedDate = ScheduleImportParser.dateKey(for: date, calendar: calendar)
        guard document.date == expectedDate else { throw ScheduleImportError.wrongDate(document.date) }
        try ScheduleValidator.validate(document.blocks)
        return document
    }

    func write(_ document: DailyScheduleDocument) throws {
        try ScheduleValidator.validate(document.blocks)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: handoffURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: handoffURL.path)
    }

    var modificationDate: Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: handoffURL.path)
        return attributes?[.modificationDate] as? Date
    }
}
