import SwiftUI

/// Lock In controls surface. TopBuddy opens assigned links in the user's
/// current macOS default browser rather than embedding or inspecting a tab.
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
            controlsContent
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                TextField("HTTPS address or localhost URL", text: $browser.addressText)
                    .textFieldStyle(.plain)
                    .onSubmit(browser.openAddress)
            }
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button("Open in \(browser.defaultBrowserName)", systemImage: "arrow.up.forward.app", action: browser.openAddress)
                .buttonStyle(.borderedProminent)
                .disabled(browser.addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("End Lock In", systemImage: "lock.open.fill", action: onEndLockIn)
                .buttonStyle(.bordered)
                .tint(.red)
        }
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
            if !browser.webResources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(browser.webResources) { resource in
                            Button {
                                browser.openResource(resource)
                            } label: {
                                Label(resource.label, systemImage: resource.openAtStart ? "arrow.up.forward.app" : "checkmark.shield")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    private var controlsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("External browser controls", systemImage: "safari")
                        .font(.title3.weight(.semibold))
                    Text("Approved links open in \(browser.defaultBrowserName), your macOS default browser. TopBuddy checks the links it opens, but it cannot inspect or block manual navigation inside an external browser without a browser extension.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if browser.webResources.isEmpty && browser.materials.isEmpty {
                    ContentUnavailableView(
                        "No focus-kit resources assigned",
                        systemImage: "link.badge.plus",
                        description: Text("Add exact websites or materials to this block's focus kit.")
                    )
                } else {
                    if !browser.webResources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assigned websites")
                                .font(.headline)
                            ForEach(browser.webResources) { resource in
                                Button {
                                    browser.openResource(resource)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "link")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(resource.label)
                                                .font(.body.weight(.medium))
                                            Text(resource.value)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text("Open")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(10)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                    if !browser.materials.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assigned materials")
                                .font(.headline)
                            ForEach(browser.materials) { material in
                                Label("\(material.label) · \(material.detail)", systemImage: material.kind.systemImage)
                                    .font(.callout)
                                    .padding(.vertical, 3)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
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
