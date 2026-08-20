import SwiftUI

@MainActor
final class NotchPresentationStore: ObservableObject {
    enum OpenReason: Sendable {
        case hover
        case click
        case drop
    }

    @Published private(set) var isExpanded = false
    @Published private(set) var isPinned = false
    @Published var selectedPage: TopBuddyNotchPage = .buddy
    @Published private(set) var geometry: NotchDisplayGeometry
    let timing: NotchInteractionTiming

    var onPresentationChanged: (() -> Void)?

    init(geometry: NotchDisplayGeometry, timing: NotchInteractionTiming = .responsive) {
        self.geometry = geometry
        self.timing = timing
    }

    func expand(reason: OpenReason, page: TopBuddyNotchPage? = nil) {
        if let page { selectedPage = page }
        if reason == .click || reason == .drop { isPinned = true }
        guard !isExpanded else {
            onPresentationChanged?()
            return
        }
        isExpanded = true
        onPresentationChanged?()
    }

    func collapse() {
        isPinned = false
        guard isExpanded else { return }
        isExpanded = false
        onPresentationChanged?()
    }

    func togglePin() {
        isPinned.toggle()
        if isPinned { isExpanded = true }
        onPresentationChanged?()
    }

    func updateGeometry(_ geometry: NotchDisplayGeometry) {
        self.geometry = geometry
        onPresentationChanged?()
    }
}
