import SwiftUI

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var now: Date
    @Published private(set) var revision = 0
    @Published private(set) var activeDocument: DailyScheduleDocument?
    @Published private(set) var handoffMessage = "No schedule imported yet."

    private var calendar: Calendar
    private let progressStore: ProgressStore
    private let handoffStore: ScheduleHandoffStore
    private var lastHandoffModificationDate: Date?

    init(
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        progressStore: ProgressStore? = nil,
        handoffStore: ScheduleHandoffStore? = nil
    ) {
        self.now = now
        self.calendar = calendar
        self.progressStore = progressStore ?? ProgressStore(calendar: calendar)
        self.handoffStore = handoffStore ?? ScheduleHandoffStore()
        reloadHandoff(force: true)
    }

    var todayBlocks: [ScheduleBlock] {
        activeDocument?.blocks ?? []
    }

    var rolloverTitles: [String] {
        activeDocument?.rollover ?? []
    }

    var handoffURL: URL { handoffStore.handoffURL }

    var currentBlock: ScheduleBlock? {
        currentBlock(at: now)
    }

    var nextBlock: ScheduleBlock? {
        nextBlock(after: now)
    }

    var petState: PetState {
        PetState.derive(
            from: currentBlock,
            isCompleted: currentBlock.map { isCompleted($0) } ?? false
        )
    }

    func refresh(at date: Date = Date()) {
        let priorDateKey = ScheduleImportParser.dateKey(for: now, calendar: calendar)
        now = date
        let nextDateKey = ScheduleImportParser.dateKey(for: now, calendar: calendar)
        reloadHandoff(force: priorDateKey != nextDateKey)
    }

    func reloadHandoff(force: Bool = false) {
        let modificationDate = handoffStore.modificationDate
        guard force || modificationDate != lastHandoffModificationDate else { return }
        lastHandoffModificationDate = modificationDate
        do {
            if let document = try handoffStore.load(for: now, calendar: calendar) {
                activeDocument = document
                handoffMessage = "Loaded \(document.source) · \(document.refreshedAt)"
            } else {
                activeDocument = nil
                handoffMessage = "No schedule imported. Paste a four-column plan or add today.json."
            }
            revision += 1
        } catch ScheduleImportError.wrongDate {
            activeDocument = nil
            handoffMessage = "The handoff file is from another day, so TopBuddy left today empty."
            revision += 1
        } catch {
            handoffMessage = "TopBuddy kept the last valid schedule because today.json is invalid: \(error.localizedDescription)"
        }
    }

    func importToday(_ document: DailyScheduleDocument) throws {
        let expectedDate = ScheduleImportParser.dateKey(for: now, calendar: calendar)
        guard document.date == expectedDate else { throw ScheduleImportError.wrongDate(document.date) }
        try handoffStore.write(document)
        activeDocument = document
        lastHandoffModificationDate = handoffStore.modificationDate
        handoffMessage = "Loaded \(document.source) · \(document.refreshedAt)"
        revision += 1
    }

    func updateResources(for blockID: String, resources: [ResourceTarget]) throws {
        let blocks = todayBlocks.map { block in
            block.id == blockID ? block.replacingResources(resources) : block
        }
        let document = DailyScheduleDocument(
            date: ScheduleImportParser.dateKey(for: now, calendar: calendar),
            refreshedAt: ISO8601DateFormatter().string(from: Date()),
            source: "Local resource rules",
            blocks: blocks,
            rollover: rolloverTitles
        )
        try importToday(document)
    }

    func adjustmentProposal(minutes: Int, hardStopMinute: Int) -> ScheduleAdjustmentProposal? {
        guard let currentBlock else { return nil }
        return ScheduleAdjustmentEngine.proposal(
            extending: currentBlock,
            by: minutes,
            in: todayBlocks,
            hardStopMinute: hardStopMinute
        )
    }

    func apply(_ proposal: ScheduleAdjustmentProposal) throws {
        guard proposal.canApply else { return }
        let document = DailyScheduleDocument(
            date: ScheduleImportParser.dateKey(for: now, calendar: calendar),
            refreshedAt: ISO8601DateFormatter().string(from: Date()),
            source: "TopBuddy-approved adjustment",
            blocks: proposal.proposedBlocks,
            rollover: rolloverTitles + proposal.rolloverTitles
        )
        try importToday(document)
    }

    func currentBlock(at date: Date) -> ScheduleBlock? {
        let minute = minutesFromMidnight(for: date)
        return blocks(for: date).first { $0.contains(minute: minute) }
    }

    func nextBlock(after date: Date) -> ScheduleBlock? {
        let minute = minutesFromMidnight(for: date)
        let laterToday = blocks(for: date)
            .filter { $0.startMinute > minute }
            .min { $0.startMinute < $1.startMinute }
        if let laterToday { return laterToday }

        return nil
    }

    func isCompleted(_ block: ScheduleBlock) -> Bool {
        progressStore.isCompleted(block, on: now)
    }

    func toggleCompletion(_ block: ScheduleBlock) {
        progressStore.setCompleted(!isCompleted(block), block: block, on: now)
        revision += 1
    }

    func secondsRemaining(in block: ScheduleBlock, at date: Date? = nil) -> TimeInterval {
        let date = date ?? now
        let minute = minutesFromMidnight(for: date)
        let second = calendar.component(.second, from: date)
        let end = block.endMinute
        let remainingMinutes: Int
        if block.endMinute >= block.startMinute {
            remainingMinutes = max(0, end - minute)
        } else if minute >= block.startMinute {
            remainingMinutes = (24 * 60 - minute) + end
        } else {
            remainingMinutes = max(0, end - minute)
        }
        return max(0, TimeInterval(remainingMinutes * 60 - second))
    }

    private func blocks(for date: Date) -> [ScheduleBlock] {
        let dateKey = ScheduleImportParser.dateKey(for: date, calendar: calendar)
        if dateKey == ScheduleImportParser.dateKey(for: now, calendar: calendar), let activeDocument {
            return activeDocument.blocks
        }
        return []
    }

    private func minutesFromMidnight(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
