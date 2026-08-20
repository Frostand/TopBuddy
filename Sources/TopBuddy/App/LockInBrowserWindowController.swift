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
        window.title = "TopBuddy Lock In controls"
        window.setContentSize(NSSize(width: 820, height: 600))
        window.minSize = NSSize(width: 680, height: 480)
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
