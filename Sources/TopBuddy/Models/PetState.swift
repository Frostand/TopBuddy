import SwiftUI

enum PetState: String, Sendable {
    case ready
    case focusing
    case traveling
    case eating
    case celebrating
    case resting
    case needsAttention

    var label: String {
        switch self {
        case .ready: "Ready"
        case .focusing: "Locked in"
        case .traveling: "On the move"
        case .eating: "Refueling"
        case .celebrating: "Nice work"
        case .resting: "Resting"
        case .needsAttention: "Needs a decision"
        }
    }

    var accent: Color {
        switch self {
        case .ready: .cyan
        case .focusing: .indigo
        case .traveling: .orange
        case .eating: .green
        case .celebrating: .mint
        case .resting: .purple
        case .needsAttention: .pink
        }
    }

    static func derive(from block: ScheduleBlock?, isCompleted: Bool) -> PetState {
        if isCompleted { return .celebrating }
        guard let block else { return .ready }
        return switch block.category {
        case .sleep: .resting
        case .commute: .traveling
        case .meal: .eating
        case .school, .homework, .competition, .research, .scioly, .extracurricular: .focusing
        case .routine: .ready
        }
    }
}
