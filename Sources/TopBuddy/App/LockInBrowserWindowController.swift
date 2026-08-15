import AppKit
import SwiftUI

@MainActor
final class LockInBrowserWindowController: NSWindowController {
    init(
        browser: FocusBrowserStore,
        lockIn: LockInStore,
        onEndLockIn: @escaping () -> Void,
        onGranted: @escaping (LockInAttempt) -> Void
    ) {
        let content = FocusBrowserWindowView(
            browser: browser,
            lockIn: lockIn,
            onEndLockIn: onEndLockIn,
            onGranted: onGranted
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "TopBuddy Lock In"
        window.setContentSize(NSSize(width: 1_060, height: 720))
        window.minSize = NSSize(width: 860, height: 620)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
