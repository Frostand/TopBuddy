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

    var id: String { "\(kind.rawValue):\(value)" }

    static func url(_ label: String, _ value: String) -> ResourceTarget {
        ResourceTarget(kind: .url, label: label, value: value)
    }

    static func application(_ label: String, bundleIdentifier: String) -> ResourceTarget {
        ResourceTarget(kind: .application, label: label, value: bundleIdentifier)
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
    let competition: Competition?

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
            competition: competition
        )
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
