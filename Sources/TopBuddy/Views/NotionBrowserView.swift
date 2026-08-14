import AppKit
import SwiftUI
import WebKit

struct NotionBrowserView: NSViewRepresentable {
    @ObservedObject var browser: NotionBrowserStore

    func makeCoordinator() -> Coordinator {
        Coordinator(browser: browser)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: browser.currentURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let command = browser.command,
              command.id != context.coordinator.lastCommandID else { return }
        context.coordinator.lastCommandID = command.id

        switch command.action {
        case .goBack:
            if webView.canGoBack { webView.goBack() }
        case .goForward:
            if webView.canGoForward { webView.goForward() }
        case .reload:
            webView.reload()
        case let .load(url):
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let browser: NotionBrowserStore
        var lastCommandID: UUID?

        init(browser: NotionBrowserStore) {
            self.browser = browser
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            update(browserFrom: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
            update(browserFrom: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            update(browserFrom: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            browser.report(error: error)
            update(browserFrom: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            browser.report(error: error)
            update(browserFrom: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if NotionURLPolicy.allowsEmbeddedNavigation(to: url) {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url,
               NotionURLPolicy.allowsEmbeddedNavigation(to: url) {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func update(browserFrom webView: WKWebView) {
            browser.updateProgress(webView.estimatedProgress)
            browser.update(
                url: webView.url,
                title: webView.title,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward,
                isLoading: webView.isLoading
            )
        }
    }
}
