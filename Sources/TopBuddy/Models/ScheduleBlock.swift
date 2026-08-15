import Foundation

enum BlockCategory: String, Codable, CaseIterable, Sendable {
    case routine
    case commute
    case school
    case extracurricular
    case meal
    case homework
    case competition
    case research
    case scioly
    case sleep

    var systemImage: String {
        switch self {
        case .routine: "sun.max.fill"
        case .commute: "car.fill"
        case .school: "building.columns.fill"
        case .extracurricular: "person.3.fill"
        case .meal: "fork.knife"
        case .homework: "book.closed.fill"
        case .competition: "target"
        case .research: "flask.fill"
        case .scioly: "atom"
        case .sleep: "moon.stars.fill"
        }
    }
}

struct Competition: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct ResourceTarget: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case url
        case application

        var id: String { rawValue }
    }

    let kind: Kind
    let label: String
    let value: String
    let openAtStart: Bool

    var id: String { "\(kind.rawValue):\(value)" }

    init(kind: Kind, label: String, value: String, openAtStart: Bool = true) {
        self.kind = kind
        self.label = label
        self.value = value
        self.openAtStart = openAtStart
    }

    static func url(_ label: String, _ value: String, openAtStart: Bool = true) -> ResourceTarget {
        ResourceTarget(kind: .url, label: label, value: value, openAtStart: openAtStart)
    }

    static func application(
        _ label: String,
        bundleIdentifier: String,
        openAtStart: Bool = true
    ) -> ResourceTarget {
        ResourceTarget(
            kind: .application,
            label: label,
            value: bundleIdentifier,
            openAtStart: openAtStart
        )
    }

    var isSafeToOpen: Bool {
        switch kind {
        case .url:
            guard let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  url.host?.isEmpty == false,
                  url.user == nil,
                  url.password == nil else { return false }
            if scheme == "https" { return true }
            if scheme == "http" {
                return url.host == "localhost" || url.host == "127.0.0.1" || url.host == "::1"
            }
            return false
        case .application:
            let components = value.split(separator: ".", omittingEmptySubsequences: false)
            return value.count <= 255
                && components.count >= 2
                && components.allSatisfy { component in
                    guard let first = component.first, let last = component.last,
                          first.isLetter || first.isNumber,
                          last.isLetter || last.isNumber else { return false }
                    return component.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
                }
        }
    }

    func replacingOpenAtStart(_ openAtStart: Bool) -> ResourceTarget {
        ResourceTarget(kind: kind, label: label, value: value, openAtStart: openAtStart)
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case label
        case value
        case openAtStart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
        value = try container.decode(String.self, forKey: .value)
        openAtStart = try container.decodeIfPresent(Bool.self, forKey: .openAtStart) ?? true
    }
}

struct ScheduleBlock: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let startMinute: Int
    let endMinute: Int
    let category: BlockCategory
    let exactActions: String
    let finishTarget: String
    let resources: [ResourceTarget]
    let materials: [StudyMaterial]
    let competition: Competition?

    init(
        id: String,
        title: String,
        startMinute: Int,
        endMinute: Int,
        category: BlockCategory,
        exactActions: String,
        finishTarget: String,
        resources: [ResourceTarget],
        materials: [StudyMaterial] = [],
        competition: Competition?
    ) {
        self.id = id
        self.title = title
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.category = category
        self.exactActions = exactActions
        self.finishTarget = finishTarget
        self.resources = resources
        self.materials = materials
        self.competition = competition
    }

    var durationMinutes: Int {
        endMinute >= startMinute
            ? endMinute - startMinute
            : (24 * 60 - startMinute) + endMinute
    }

    func contains(minute: Int) -> Bool {
        if endMinute >= startMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }

    var timeLabel: String {
        "\(Self.format(minute: startMinute))–\(Self.format(minute: endMinute))"
    }

    func replacingTimes(startMinute: Int? = nil, endMinute: Int? = nil) -> ScheduleBlock {
        ScheduleBlock(
            id: id,
            title: title,
            startMinute: startMinute ?? self.startMinute,
            endMinute: endMinute ?? self.endMinute,
            category: category,
            exactActions: exactActions,
            finishTarget: finishTarget,
            resources: resources,
            materials: materials,
            competition: competition
        )
    }

    func replacingResources(_ resources: [ResourceTarget]) -> ScheduleBlock {
        ScheduleBlock(
            id: id,
            title: title,
            startMinute: startMinute,
            endMinute: endMinute,
            category: category,
            exactActions: exactActions,
            finishTarget: finishTarget,
            resources: resources,
            materials: materials,
            competition: competition
        )
    }

    func replacingFocusKit(
        resources: [ResourceTarget],
        materials: [StudyMaterial]
    ) -> ScheduleBlock {
        ScheduleBlock(
            id: id,
            title: title,
            startMinute: startMinute,
            endMinute: endMinute,
            category: category,
            exactActions: exactActions,
            finishTarget: finishTarget,
            resources: resources,
            materials: materials,
            competition: competition
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case startMinute
        case endMinute
        case category
        case exactActions
        case finishTarget
        case resources
        case materials
        case competition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        category = try container.decode(BlockCategory.self, forKey: .category)
        exactActions = try container.decode(String.self, forKey: .exactActions)
        finishTarget = try container.decode(String.self, forKey: .finishTarget)
        resources = try container.decodeIfPresent([ResourceTarget].self, forKey: .resources) ?? []
        materials = try container.decodeIfPresent([StudyMaterial].self, forKey: .materials) ?? []
        competition = try container.decodeIfPresent(Competition.self, forKey: .competition)
    }

    private static func format(minute: Int) -> String {
        let normalized = minute % (24 * 60)
        let hour24 = normalized / 60
        let minutePart = normalized % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minutePart, suffix)
    }
}
