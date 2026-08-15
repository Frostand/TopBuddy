import AppKit
import Foundation

enum TopBuddyNotchPage: String, CaseIterable, Identifiable, Sendable {
    case buddy
    case music
    case agenda
    case shelf
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buddy: "Buddy"
        case .music: "Music"
        case .agenda: "Agenda"
        case .shelf: "Shelf"
        case .focus: "Focus"
        }
    }

    var systemImage: String {
        switch self {
        case .buddy: "pawprint.fill"
        case .music: "music.note"
        case .agenda: "calendar"
        case .shelf: "tray.full.fill"
        case .focus: "timer"
        }
    }
}
struct NotchDisplayGeometry: Equatable, Sendable {
    let screenFrame: CGRect
    let visibleFrame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryLeftWidth: CGFloat?
    let auxiliaryRightWidth: CGFloat?

    var menuBarHeight: CGFloat {
        max(24, screenFrame.maxY - visibleFrame.maxY)
    }

    var physicalNotchWidth: CGFloat {
        guard let auxiliaryLeftWidth, let auxiliaryRightWidth else { return 188 }
        let measured = screenFrame.width - auxiliaryLeftWidth - auxiliaryRightWidth
        return min(260, max(148, measured + 4))
    }

    var physicalNotchHeight: CGFloat {
        safeAreaTop > 0 ? safeAreaTop : menuBarHeight
    }

    var closedSize: CGSize {
        CGSize(
            width: min(screenFrame.width - 24, physicalNotchWidth + 112),
            height: max(34, physicalNotchHeight + 8)
        )
    }

    var expandedSize: CGSize {
        CGSize(
            width: min(720, screenFrame.width - 40),
            height: min(392, screenFrame.height * 0.48)
        )
    }

    func windowFrame(expanded: Bool) -> CGRect {
        let size = expanded ? expandedSize : closedSize
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        ).integral
    }

    var activationRect: CGRect {
        windowFrame(expanded: false).insetBy(dx: -18, dy: -10)
    }
}

struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let path: String
    let addedAt: Date

    init(id: UUID = UUID(), url: URL, addedAt: Date = Date()) {
        self.id = id
        path = url.standardizedFileURL.path
        self.addedAt = addedAt
    }

    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

struct AgendaEvent: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let isAllDay: Bool
}

enum FocusTimerPreset: String, CaseIterable, Identifiable, Sendable {
    case focus25
    case focus50
    case eyeBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus25: "Focus 25"
        case .focus50: "Focus 50"
        case .eyeBreak: "20-20-20"
        }
    }

    var initialSeconds: Int {
        switch self {
        case .focus25: 25 * 60
        case .focus50: 50 * 60
        case .eyeBreak: 20 * 60
        }
    }
}
