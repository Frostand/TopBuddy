import AppKit
import Foundation

@MainActor
final class MusicHubStore: ObservableObject {
    @Published private(set) var snapshot = MusicPlaybackSnapshot.notRunning
    @Published private(set) var artworkData: Data?
    @Published private(set) var playlists: [MusicPlaylist] = []
    @Published private(set) var isMusicRunning = false
    @Published private(set) var isBusy = false
    @Published private(set) var controlsEnabled: Bool
    @Published var errorMessage: String?

    private static let controlsEnabledKey = "topbuddy.music.controls-enabled"
    private let client: MusicAutomationClient
    private let defaults: UserDefaults
    private let workspace: NSWorkspace
    private var loadedArtworkIdentity: String?

    init(
        client: MusicAutomationClient = MusicAutomationClient(),
        defaults: UserDefaults = .standard,
        workspace: NSWorkspace = .shared
    ) {
        self.client = client
        self.defaults = defaults
        self.workspace = workspace
        controlsEnabled = defaults.bool(forKey: Self.controlsEnabledKey)
        updateRunningState()
    }

    func prepare() async {
        updateRunningState()
        if controlsEnabled && isMusicRunning {
            await refreshAll()
        }
    }

    func monitorPlayback() async {
        await prepare()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await refreshPlayback()
        }
    }

    func enableControls() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil

        if !isMusicRunning {
            launchMusic(activates: false)
            try? await Task.sleep(for: .seconds(1))
            updateRunningState()
        }

        do {
            let nextSnapshot = try await client.playbackSnapshot()
            await apply(nextSnapshot, forceArtworkRefresh: true)
            playlists = try await client.playlists()
            controlsEnabled = true
            defaults.set(true, forKey: Self.controlsEnabledKey)
        } catch {
            controlsEnabled = false
            defaults.set(false, forKey: Self.controlsEnabledKey)
            errorMessage = error.localizedDescription
        }
    }

    func disableControls() {
        controlsEnabled = false
        defaults.set(false, forKey: Self.controlsEnabledKey)
        playlists = []
        errorMessage = nil
        resetPlayback()
    }

    func refreshPlayback() async {
        updateRunningState()
        guard controlsEnabled, isMusicRunning, !isBusy else {
            if !isMusicRunning { resetPlayback() }
            return
        }
        do {
            let nextSnapshot = try await client.playbackSnapshot()
            await apply(nextSnapshot)
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func refreshAll() async {
        guard controlsEnabled, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        updateRunningState()
        guard isMusicRunning else {
            resetPlayback()
            return
        }
        do {
            async let nextSnapshot = client.playbackSnapshot()
            async let nextPlaylists = client.playlists()
            let fetchedSnapshot = try await nextSnapshot
            let fetchedPlaylists = try await nextPlaylists
            await apply(fetchedSnapshot, forceArtworkRefresh: true)
            playlists = fetchedPlaylists
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func perform(_ command: MusicAutomationCommand) async {
        guard controlsEnabled else {
            errorMessage = "Enable Apple Music controls first."
            return
        }
        do {
            try await client.perform(command)
            try? await Task.sleep(for: .milliseconds(180))
            let nextSnapshot = try await client.playbackSnapshot()
            await apply(nextSnapshot)
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func setLocalPosition(_ value: Double) {
        snapshot.position = min(snapshot.duration, max(0, value))
    }

    func setLocalVolume(_ value: Int) {
        snapshot.volume = min(100, max(0, value))
    }

    func setLocalShuffle(_ enabled: Bool) {
        snapshot.shuffleEnabled = enabled
    }

    func openMusic() {
        launchMusic(activates: true)
    }

    func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        workspace.open(url)
    }

    private func updateRunningState() {
        isMusicRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.Music"
        ).isEmpty
    }

    private func launchMusic(activates: Bool) {
        guard let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.Music") else {
            errorMessage = MusicAutomationError.musicUnavailable.localizedDescription
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        configuration.addsToRecentItems = false
        workspace.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.errorMessage = error.localizedDescription }
                self?.updateRunningState()
            }
        }
    }

    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
        if error as? MusicAutomationError == .permissionDenied {
            controlsEnabled = false
            defaults.set(false, forKey: Self.controlsEnabledKey)
            resetPlayback()
        }
    }

    private func apply(
        _ nextSnapshot: MusicPlaybackSnapshot,
        forceArtworkRefresh: Bool = false
    ) async {
        let nextIdentity = nextSnapshot.artworkIdentity
        let shouldLoadArtwork = nextIdentity != nil && (
            forceArtworkRefresh || nextIdentity != loadedArtworkIdentity
        )

        snapshot = nextSnapshot

        guard let nextIdentity else {
            loadedArtworkIdentity = nil
            artworkData = nil
            return
        }
        guard shouldLoadArtwork else { return }

        loadedArtworkIdentity = nextIdentity
        let nextArtwork = try? await client.currentArtworkData()
        guard snapshot.artworkIdentity == nextIdentity else { return }
        artworkData = nextArtwork
    }

    private func resetPlayback() {
        snapshot = .notRunning
        artworkData = nil
        loadedArtworkIdentity = nil
    }
}
