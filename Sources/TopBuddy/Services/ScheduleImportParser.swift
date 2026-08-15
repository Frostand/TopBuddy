import Foundation

enum ScheduleImportError: LocalizedError, Equatable {
    case noRows
    case unsupportedSchema(Int)
    case malformedRow(Int)
    case invalidTime(String)
    case invalidBlock(String)
    case invalidResource(String)
    case invalidMaterial(String)
    case duplicateID(String)
    case overlap(String, String)
    case wrongDate(String)

    var errorDescription: String? {
        switch self {
        case .noRows:
            "No schedule rows were found. Paste a four-column Markdown table or tab-separated rows."
        case let .unsupportedSchema(version):
            "Schedule schema version \(version) is not supported. TopBuddy accepts versions 1 and 2."
        case let .malformedRow(line):
            "Line \(line) does not have Time, Task, Exact actions, and Finish target columns."
        case let .invalidTime(value):
            "Could not read the time range “\(value)”. Include AM/PM on at least one side."
        case let .invalidBlock(title):
            "\(title) has an invalid or zero-length time range."
        case let .invalidResource(label):
            "\(label) is not a safe HTTPS, localhost, or application resource."
        case let .invalidMaterial(label):
            "\(label) is not a valid study material entry."
        case let .duplicateID(id):
            "The schedule contains a duplicate block ID: \(id)."
        case let .overlap(first, second):
            "\(first) overlaps \(second). Fix the times before importing."
        case let .wrongDate(date):
            "The handoff is for \(date), not today."
        }
    }
}

enum ScheduleValidator {
    static func validate(_ blocks: [ScheduleBlock]) throws {
        guard !blocks.isEmpty else { throw ScheduleImportError.noRows }
        var identifiers = Set<String>()
        for block in blocks {
            guard identifiers.insert(block.id).inserted else {
                throw ScheduleImportError.duplicateID(block.id)
            }
            guard (0..<(24 * 60)).contains(block.startMinute),
                  (0..<(24 * 60)).contains(block.endMinute) else {
                throw ScheduleImportError.invalidBlock(block.title)
            }
            guard block.endMinute != block.startMinute else {
                throw ScheduleImportError.invalidBlock(block.title)
            }
            if block.category != .sleep && block.endMinute <= block.startMinute {
                throw ScheduleImportError.invalidBlock(block.title)
            }
            if let invalid = block.resources.first(where: { !$0.isSafeToOpen }) {
                throw ScheduleImportError.invalidResource(invalid.label)
            }
            if let invalid = block.materials.first(where: { !$0.isValid }) {
                throw ScheduleImportError.invalidMaterial(invalid.label)
            }
        }

        let spans = blocks.flatMap { block -> [(start: Int, end: Int, title: String)] in
            if block.endMinute > block.startMinute {
                return [(block.startMinute, block.endMinute, block.title)]
            }
            return [
                (block.startMinute, 24 * 60, block.title),
                (0, block.endMinute, block.title)
            ]
        }
        .sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
        for pair in zip(spans, spans.dropFirst()) where pair.1.start < pair.0.end {
            throw ScheduleImportError.overlap(pair.0.title, pair.1.title)
        }
    }
}

struct ScheduleImportParser {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func parse(_ text: String, for date: Date = Date(), source: String = "Pasted schedule") throws -> DailyScheduleDocument {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [ScheduleBlock] = []

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let columns = splitColumns(line)
            guard !isHeader(columns), !isSeparator(columns) else { continue }
            guard columns.count >= 4 else {
                if line.contains("|") || line.contains("\t") {
                    throw ScheduleImportError.malformedRow(index + 1)
                }
                continue
            }

            let (start, end) = try parseTimeRange(columns[0])
            let title = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw ScheduleImportError.malformedRow(index + 1) }
            let category = ScheduleResourceCatalog.inferredCategory(for: title)
            blocks.append(
                ScheduleBlock(
                    id: stableID(title: title, start: start),
                    title: title,
                    startMinute: start,
                    endMinute: end,
                    category: category,
                    exactActions: columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                    finishTarget: columns[3...].joined(separator: " | ").trimmingCharacters(in: .whitespacesAndNewlines),
                    resources: ScheduleResourceCatalog.inferredResources(for: title),
                    materials: [],
                    competition: ScheduleResourceCatalog.inferredCompetition(for: title)
                )
            )
        }

        blocks.sort { $0.startMinute < $1.startMinute }
        try ScheduleValidator.validate(blocks)
        return DailyScheduleDocument(
            date: Self.dateKey(for: date, calendar: calendar),
            refreshedAt: ISO8601DateFormatter().string(from: Date()),
            source: source,
            blocks: blocks
        )
    }

    static func dateKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func splitColumns(_ line: String) -> [String] {
        if line.contains("\t") {
            return line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        }
        guard line.contains("|") else { return [] }
        var columns = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if columns.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { columns.removeFirst() }
        if columns.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { columns.removeLast() }
        return columns
    }

    private func isHeader(_ columns: [String]) -> Bool {
        guard columns.count >= 2 else { return false }
        return columns[0].lowercased().contains("time") && columns[1].lowercased().contains("task")
    }

    private func isSeparator(_ columns: [String]) -> Bool {
        !columns.isEmpty && columns.allSatisfy { column in
            let trimmed = column.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && trimmed.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private func parseTimeRange(_ rawValue: String) throws -> (Int, Int) {
        let pattern = #"^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?\s*[–—-]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?\s*$"#
        let expression = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(rawValue.startIndex..<rawValue.endIndex, in: rawValue)
        guard let match = expression.firstMatch(in: rawValue, range: range) else {
            throw ScheduleImportError.invalidTime(rawValue)
        }
        func capture(_ index: Int) -> String? {
            let matchRange = match.range(at: index)
            guard matchRange.location != NSNotFound,
                  let swiftRange = Range(matchRange, in: rawValue) else { return nil }
            return String(rawValue[swiftRange])
        }
        guard let startHour = capture(1).flatMap(Int.init),
              let endHour = capture(4).flatMap(Int.init) else {
            throw ScheduleImportError.invalidTime(rawValue)
        }
        let startMinute = capture(2).flatMap(Int.init) ?? 0
        let endMinute = capture(5).flatMap(Int.init) ?? 0
        let startSuffix = capture(3)?.uppercased() ?? capture(6)?.uppercased()
        let endSuffix = capture(6)?.uppercased() ?? capture(3)?.uppercased()
        guard let startSuffix, let endSuffix,
              (1...12).contains(startHour), (1...12).contains(endHour),
              (0...59).contains(startMinute), (0...59).contains(endMinute) else {
            throw ScheduleImportError.invalidTime(rawValue)
        }
        return (
            minutes(hour: startHour, minute: startMinute, suffix: startSuffix),
            minutes(hour: endHour, minute: endMinute, suffix: endSuffix)
        )
    }

    private func minutes(hour: Int, minute: Int, suffix: String) -> Int {
        let base = hour % 12 + (suffix == "PM" ? 12 : 0)
        return base * 60 + minute
    }

    private func stableID(title: String, start: Int) -> String {
        let slug = title.lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
        let compact = String(slug).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "import-\(start)-\(String(compact.prefix(48)))"
    }
}
