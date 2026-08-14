import Foundation

struct CoachMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable {
        case user
        case pet
    }

    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct ScheduleAdjustmentProposal: Identifiable, Equatable, Sendable {
    let id: UUID
    let requestedMinutes: Int
    let targetBlockID: String
    let summary: String
    let proposedBlocks: [ScheduleBlock]
    let rolloverTitles: [String]
    let canApply: Bool

    init(
        id: UUID = UUID(),
        requestedMinutes: Int,
        targetBlockID: String,
        summary: String,
        proposedBlocks: [ScheduleBlock],
        rolloverTitles: [String],
        canApply: Bool
    ) {
        self.id = id
        self.requestedMinutes = requestedMinutes
        self.targetBlockID = targetBlockID
        self.summary = summary
        self.proposedBlocks = proposedBlocks
        self.rolloverTitles = rolloverTitles
        self.canApply = canApply
    }
}
