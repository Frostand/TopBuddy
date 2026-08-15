import AppKit
import QuartzCore
import SwiftUI

private final class TopBuddyNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // AppKit normally pushes borderless panels below the menu bar. TopBuddy
        // intentionally occupies the physical notch region, so retain the exact
        // top-anchored frame calculated from the display's safe-area geometry.
        frameRect
    }
}

@MainActor
final class TopBuddyNotchPanelController {
    private let model: AppModel
    private let panel: TopBuddyNotchPanel
    private let presentation: NotchPresentationStore
    private var pointerTimer: Timer?
    private var exitDeadline: Date?
    private var screenObserver: NSObjectProtocol?

    var isVisible: Bool { panel.isVisible }

    init(model: AppModel) {
        self.model = model
        let geometry = Self.geometry(for: Self.targetScreen())
        presentation = NotchPresentationStore(geometry: geometry)
        panel = TopBuddyNotchPanel(
            contentRect: geometry.windowFrame(expanded: false),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .mainMenu + 3
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.sharingType = .readOnly

        let rootView = TopBuddyNotchView(presentation: presentation)
            .environmentObject(model)
            .environmentObject(model.schedule)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        presentation.onPresentationChanged = { [weak self] in
            self?.updateFrame(animated: true)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.screenConfigurationChanged() }
        }
    }

    func show() {
        screenConfigurationChanged()
        panel.orderFrontRegardless()
        startPointerTracking()
    }

    func hide() {
        pointerTimer?.invalidate()
        pointerTimer = nil
        presentation.collapse()
        panel.orderOut(nil)
    }

    func open(page: TopBuddyNotchPage = .buddy, pinned: Bool = true) {
        presentation.expand(reason: pinned ? .click : .hover, page: page)
        panel.orderFrontRegardless()
    }

    private func startPointerTracking() {
        guard pointerTimer == nil else { return }
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.samplePointer() }
        }
        pointerTimer?.tolerance = 0.02
    }

    private func samplePointer(now: Date = Date()) {
        guard panel.isVisible else { return }
        let point = NSEvent.mouseLocation

        if !presentation.isExpanded {
            exitDeadline = nil
            if presentation.geometry.activationRect.contains(point) {
                presentation.expand(
                    reason: .hover,
                    page: model.musicHub.snapshot.shouldShowCompactNowPlaying ? .music : nil
                )
            }
            return
        }

        let interactiveFrame = panel.frame.insetBy(dx: -18, dy: -12)
        if interactiveFrame.contains(point) || presentation.isPinned || panel.isKeyWindow {
            exitDeadline = nil
            return
        }

        if exitDeadline == nil {
            exitDeadline = now.addingTimeInterval(0.55)
        } else if let exitDeadline, now >= exitDeadline {
            self.exitDeadline = nil
            presentation.collapse()
        }
    }

    private func screenConfigurationChanged() {
        let geometry = Self.geometry(for: Self.targetScreen())
        presentation.updateGeometry(geometry)
        updateFrame(animated: false)
    }

    private func updateFrame(animated: Bool) {
        let targetFrame = presentation.geometry.windowFrame(expanded: presentation.isExpanded)
        guard panel.frame != targetFrame else { return }

        let update = { self.panel.setFrame(targetFrame, display: true) }
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            update()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.82, 0.2, 1)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(displayID) != 0 && screen.safeAreaInsets.top > 0
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func geometry(for screen: NSScreen?) -> NotchDisplayGeometry {
        guard let screen else {
            let fallback = CGRect(x: 0, y: 0, width: 1_440, height: 900)
            return NotchDisplayGeometry(
                screenFrame: fallback,
                visibleFrame: fallback.insetBy(dx: 0, dy: 24),
                safeAreaTop: 32,
                auxiliaryLeftWidth: nil,
                auxiliaryRightWidth: nil
            )
        }
        return NotchDisplayGeometry(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width
        )
    }
}
