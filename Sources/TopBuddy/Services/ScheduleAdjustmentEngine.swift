import Foundation

enum MoreTimeRequestParser {
    static func minutes(in message: String) -> Int? {
        let normalized = message.lowercased()
        guard isMoreTimeIntent(normalized) else {
            return nil
        }
        let pattern = #"(\d{1,3})\s*(?:more\s*)?(minutes?|mins?|m\b|hours?|hrs?|h\b)"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = expression.firstMatch(in: normalized, range: range),
              let numberRange = Range(match.range(at: 1), in: normalized),
              let unitRange = Range(match.range(at: 2), in: normalized),
              let value = Int(normalized[numberRange]) else { return nil }
        let unit = normalized[unitRange]
        return unit.hasPrefix("h") ? value * 60 : value
    }

    static func isMoreTimeIntent(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("more time")
            || normalized.contains("more minute")
            || normalized.contains("more hour")
            || normalized.contains("extra time")
            || normalized.contains("extend")
            || normalized.contains("longer")
    }
}

enum ScheduleAdjustmentEngine {
    static func proposal(
        extending target: ScheduleBlock,
        by minutes: Int,
        in blocks: [ScheduleBlock],
        hardStopMinute: Int = 23 * 60
    ) -> ScheduleAdjustmentProposal {
        guard (1...180).contains(minutes),
              let targetIndex = blocks.firstIndex(where: { $0.id == target.id }) else {
            return ScheduleAdjustmentProposal(
                requestedMinutes: minutes,
                targetBlockID: target.id,
                summary: "Ask for between 1 and 180 additional minutes.",
                proposedBlocks: blocks,
                rolloverTitles: [],
                canApply: false
            )
        }

        let movableCategories: Set<BlockCategory> = [.routine, .homework, .competition, .research, .scioly]
        var proposed = Array(blocks.prefix(targetIndex))
        let extended = target.replacingTimes(endMinute: target.endMinute + minutes)
        guard extended.endMinute <= hardStopMinute else {
            return ScheduleAdjustmentProposal(
                requestedMinutes: minutes,
                targetBlockID: target.id,
                summary: "That would move \(target.title) past the \(timeLabel(hardStopMinute)) hard stop, so TopBuddy will not apply it.",
                proposedBlocks: blocks,
                rolloverTitles: [],
                canApply: false
            )
        }
        proposed.append(extended)

        var previousEnd = extended.endMinute
        var rollover: [String] = []
        let laterBlocks = blocks.dropFirst(targetIndex + 1)
        for block in laterBlocks {
            if block.category == .sleep {
                proposed.append(block)
                continue
            }
            let shiftedStart = max(block.startMinute, previousEnd)
            if shiftedStart > block.startMinute && !movableCategories.contains(block.category) {
                return ScheduleAdjustmentProposal(
                    requestedMinutes: minutes,
                    targetBlockID: target.id,
                    summary: "\(block.title) is fixed at \(block.timeLabel), so there is not enough safe room to extend \(target.title).",
                    proposedBlocks: blocks,
                    rolloverTitles: [],
                    canApply: false
                )
            }
            let shiftedEnd = shiftedStart + block.durationMinutes
            if shiftedEnd > hardStopMinute {
                rollover.append(block.title)
                rollover.append(contentsOf: laterBlocks.drop { $0.id != block.id }.dropFirst().filter { $0.category != .sleep }.map(\.title))
                break
            }
            let shifted = block.replacingTimes(startMinute: shiftedStart, endMinute: shiftedEnd)
            proposed.append(shifted)
            previousEnd = shifted.endMinute
        }

        if let sleep = blocks.first(where: { $0.category == .sleep }), !proposed.contains(where: { $0.id == sleep.id }) {
            proposed.append(sleep)
        }
        let rolloverText = rollover.isEmpty
            ? "No work rolls over; an existing gap absorbs the change."
            : "Rollover, in order: \(rollover.joined(separator: ", "))."
        return ScheduleAdjustmentProposal(
            requestedMinutes: minutes,
            targetBlockID: target.id,
            summary: "Extend \(target.title) by \(minutes) minutes. \(rolloverText) Fixed commitments and sleep stay unchanged.",
            proposedBlocks: proposed,
            rolloverTitles: rollover,
            canApply: true
        )
    }

    private static func timeLabel(_ minute: Int) -> String {
        let normalized = minute % (24 * 60)
        let hour24 = normalized / 60
        let minutePart = normalized % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minutePart, suffix)
    }
}
