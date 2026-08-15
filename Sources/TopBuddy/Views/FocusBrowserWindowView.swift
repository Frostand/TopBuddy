import SwiftUI

struct FocusBrowserWindowView: View {
    @ObservedObject var browser: FocusBrowserStore
    @ObservedObject var lockIn: LockInStore
    let onEndLockIn: () -> Void
    let onGranted: (LockInAttempt) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            contextStrip
            if let errorMessage = browser.errorMessage {
                errorBanner(errorMessage)
            }
            LockInExceptionView(lockIn: lockIn, onGranted: onGranted)
                .padding(.horizontal, 12)
                .padding(.bottom, lockIn.pendingAttempt == nil ? 0 : 10)
            Divider()
            FocusBrowserView(browser: browser)
                .overlay {
                    if browser.webResources.isEmpty {
                        ContentUnavailableView(
                            "No websites assigned",
                            systemImage: "link.badge.plus",
                            description: Text("Add exact sites to this block’s focus kit. Apps and physical materials can still be used.")
                        )
                    }
                }
                .overlay(alignment: .top) {
                    if browser.isLoading {
                        ProgressView(value: browser.estimatedProgress)
                            .progressViewStyle(.linear)
                    }
                }
        }
        .frame(minWidth: 860, minHeight: 620)
    }

    private var toolbar: some View {
        HStack(spacing: 9) {
            Button(action: browser.goBack) { Image(systemName: "chevron.left") }
                .disabled(!browser.canGoBack)
            Button(action: browser.goForward) { Image(systemName: "chevron.right") }
                .disabled(!browser.canGoForward)
            Button(action: browser.reload) { Image(systemName: "arrow.clockwise") }

            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                TextField("Allowed website", text: $browser.addressText)
                    .textFieldStyle(.plain)
                    .onSubmit(browser.loadAddress)
            }
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button("Go", action: browser.loadAddress)
            Button("End Lock In", systemImage: "lock.open.fill", action: onEndLockIn)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .buttonStyle(.borderless)
        .padding(10)
        .background(.bar)
    }

    private var contextStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(browser.blockTitle, systemImage: "target")
                    .font(.headline)
                Spacer()
                Text(lockIn.lastEvent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(browser.webResources) { resource in
                        Button {
                            browser.requestLoad(resource)
                        } label: {
                            Label(resource.label, systemImage: resource.openAtStart ? "arrow.up.forward.app" : "checkmark.shield")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    ForEach(browser.materials) { material in
                        Label("\(material.label) · \(material.detail)", systemImage: material.kind.systemImage)
                            .font(.caption)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.05), in: Capsule())
                    }
                }
            }
        }
        .padding(12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .lineLimit(2)
            Spacer()
            Button("Dismiss") { browser.errorMessage = nil }
                .controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.09))
    }
}
