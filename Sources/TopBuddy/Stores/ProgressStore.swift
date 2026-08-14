import Foundation

@MainActor
final class ProgressStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey = "topbuddy.completed-blocks.v1"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func isCompleted(_ block: ScheduleBlock, on date: Date) -> Bool {
        completedKeys.contains(key(for: block, on: date))
    }

    func setCompleted(_ completed: Bool, block: ScheduleBlock, on date: Date) {
        var keys = completedKeys
        let itemKey = key(for: block, on: date)
        if completed {
            keys.insert(itemKey)
        } else {
            keys.remove(itemKey)
        }
        defaults.set(Array(keys).sorted(), forKey: storageKey)
    }

    private var completedKeys: Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    private func key(for block: ScheduleBlock, on date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let datePart = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return "\(datePart)|\(block.id)"
    }
}
