import AppKit
import SwiftUI

struct NotionWorkspaceView: View {
    @ObservedObject var browser: NotionBrowserStore

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let error = browser.errorMessage {
                errorBanner(error)
            }
            NotionBrowserView(browser: browser)
                .overlay(alignment: .top) {
                    if browser.isLoading {
                        ProgressView(value: browser.estimatedProgress)
                            .progressViewStyle(.linear)
                    }
                }
        }
        .navigationTitle(browser.pageTitle)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: browser.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!browser.canGoBack)
            .help("Back")

            Button(action: browser.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!browser.canGoForward)
            .help("Forward")

            Button(action: browser.reload) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload")

            Button(action: browser.goHome) {
                Image(systemName: "house")
            }
            .help("Notion home")

            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Notion URL", text: $browser.addressText)
                    .textFieldStyle(.plain)
                    .onSubmit(browser.loadAddress)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button("Go", action: browser.loadAddress)
                .keyboardShortcut(.return, modifiers: [.command])

            Button {
                NSWorkspace.shared.open(browser.currentURL)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .help("Open this page in the Notion app or default browser")
        }
        .buttonStyle(.borderless)
        .padding(10)
        .background(.bar)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .lineLimit(2)
            Spacer()
            Button("Dismiss") { browser.errorMessage = nil }
                .controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
    }
}
