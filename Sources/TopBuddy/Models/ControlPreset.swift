import Foundation

enum ControlPreset: String, CaseIterable, Identifiable, Sendable {
    case observe
    case assist
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .observe: "Observe"
        case .assist: "Assist"
        case .focus: "Focus"
        }
    }

    var summary: String {
        switch self {
        case .observe: "Show the plan and pet. Never open or hide apps automatically."
        case .assist: "Keep the notch visible and open resources only when you press Start."
        case .focus: "Open assigned resources at block changes and hide unrelated apps."
        }
    }

    var showNotch: Bool { self != .observe }
    var autoOpenResources: Bool { self == .focus }
    var autoHideDistractions: Bool { self == .focus }
    var quitReviewEnabled: Bool { self != .observe }
}
