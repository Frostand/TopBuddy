import Foundation

enum MusicAutomationError: LocalizedError, Equatable, Sendable {
    case musicUnavailable
    case permissionDenied
    case invalidPlaylistIdentifier
    case invalidResponse
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .musicUnavailable:
            "Apple Music is not available on this Mac."
        case .permissionDenied:
            "TopBuddy does not have permission to control Music. Enable it in System Settings → Privacy & Security → Automation."
        case .invalidPlaylistIdentifier:
            "That playlist identifier is not safe to send to Music."
        case .invalidResponse:
            "Music returned an unreadable response."
        case let .commandFailed(message):
            message.isEmpty ? "Music could not complete that command." : message
        }
    }
}

enum MusicAutomationCommand: Equatable, Sendable {
    case playPause
    case previousTrack
    case nextTrack
    case setVolume(Int)
    case seek(Double)
    case setShuffle(Bool)
    case playPlaylist(String)
}

actor MusicAutomationClient {
    func playbackSnapshot() throws -> MusicPlaybackSnapshot {
        let output = try execute(
            """
            tell application "Music"
              set fieldSeparator to ASCII character 30
              set stateText to (player state as text)
              set trackName to ""
              set artistName to ""
              set albumName to ""
              set durationText to "0"
              try
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set durationText to (duration of current track as text)
              end try
              set positionText to (player position as text)
              set volumeText to (sound volume as text)
              set shuffleText to (shuffle enabled as text)
              set repeatText to (song repeat as text)
              return stateText & fieldSeparator & trackName & fieldSeparator & artistName & fieldSeparator & albumName & fieldSeparator & durationText & fieldSeparator & positionText & fieldSeparator & volumeText & fieldSeparator & shuffleText & fieldSeparator & repeatText
            end tell
            """
        )
        return try MusicPlaybackSnapshot(serialized: output)
    }

    func playlists(limit: Int = 80) throws -> [MusicPlaylist] {
        let boundedLimit = min(150, max(1, limit))
        let output = try execute(
            """
            tell application "Music"
              set fieldSeparator to ASCII character 30
              set rowSeparator to ASCII character 31
              set output to ""
              set candidates to every user playlist
              set itemCount to count candidates
              if itemCount > \(boundedLimit) then set itemCount to \(boundedLimit)
              repeat with itemIndex from 1 to itemCount
                set thePlaylist to item itemIndex of candidates
                try
                  set output to output & (persistent ID of thePlaylist) & fieldSeparator & (name of thePlaylist) & fieldSeparator & ((count tracks of thePlaylist) as text) & fieldSeparator & ((duration of thePlaylist) as text) & rowSeparator
                end try
              end repeat
              return output
            end tell
            """
        )
        return MusicPlaylist.parseList(output)
    }

    func currentArtworkData() throws -> Data? {
        let artworkURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyArtwork-\(UUID().uuidString)", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: artworkURL) }
        guard FileManager.default.createFile(
            atPath: artworkURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw MusicAutomationError.commandFailed("TopBuddy could not prepare a private artwork cache file.")
        }

        let output = try execute(
            """
            set targetFile to POSIX file \(Self.appleScriptLiteral(artworkURL.path))
            tell application "Music"
              if player state is stopped then return "none"
              try
                set artworkBytes to data of artwork 1 of current track
              on error
                return "none"
              end try
            end tell
            try
              set fileReference to open for access targetFile with write permission
              set eof fileReference to 0
              write artworkBytes to fileReference starting at 0
              close access fileReference
            on error errorMessage number errorNumber
              try
                close access targetFile
              end try
              error errorMessage number errorNumber
            end try
            return "written"
            """
        )

        guard output == "written",
              let size = try? artworkURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0,
              size <= 25 * 1_024 * 1_024 else {
            return nil
        }
        return try Data(contentsOf: artworkURL, options: .mappedIfSafe)
    }

    func perform(_ command: MusicAutomationCommand) throws {
        let source: String
        switch command {
        case .playPause:
            source = "tell application \"Music\" to playpause"
        case .previousTrack:
            source = "tell application \"Music\" to previous track"
        case .nextTrack:
            source = "tell application \"Music\" to next track"
        case let .setVolume(value):
            source = "tell application \"Music\" to set sound volume to \(min(100, max(0, value)))"
        case let .seek(position):
            let safePosition = min(86_400, max(0, position))
            let formatted = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), safePosition)
            source = "tell application \"Music\" to set player position to \(formatted)"
        case let .setShuffle(enabled):
            source = "tell application \"Music\" to set shuffle enabled to \(enabled ? "true" : "false")"
        case let .playPlaylist(identifier):
            guard MusicPlaylist.isValidPersistentID(identifier) else {
                throw MusicAutomationError.invalidPlaylistIdentifier
            }
            source = "tell application \"Music\" to play (some playlist whose persistent ID is \"\(identifier.uppercased())\")"
        }
        _ = try execute(source)
    }

    private func execute(_ source: String) throws -> String {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw MusicAutomationError.musicUnavailable
        }

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorText = String(decoding: errorData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            let lowercase = errorText.lowercased()
            if lowercase.contains("-1743") || lowercase.contains("not authorized") || lowercase.contains("not permitted") {
                throw MusicAutomationError.permissionDenied
            }
            throw MusicAutomationError.commandFailed(errorText)
        }
        return output
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
