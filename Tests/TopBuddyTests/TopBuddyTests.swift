import Foundation
import XCTest
@testable import TopBuddy

final class TopBuddyTests: XCTestCase {
    func testControlPresetsNeverGrantExternalPermissions() {
        XCTAssertFalse(ControlPreset.observe.showNotch)
        XCTAssertFalse(ControlPreset.observe.autoOpenResources)
        XCTAssertFalse(ControlPreset.observe.autoHideDistractions)
        XCTAssertFalse(ControlPreset.observe.quitReviewEnabled)

        XCTAssertTrue(ControlPreset.assist.showNotch)
        XCTAssertFalse(ControlPreset.assist.autoOpenResources)
        XCTAssertFalse(ControlPreset.assist.autoHideDistractions)

        XCTAssertTrue(ControlPreset.focus.showNotch)
        XCTAssertTrue(ControlPreset.focus.autoOpenResources)
        XCTAssertTrue(ControlPreset.focus.autoHideDistractions)
    }

    @MainActor
    func testPublicBuildShipsWithNoSchedule() throws {
        let suiteName = "TopBuddyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyEmptyScheduleTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ScheduleStore(
            progressStore: ProgressStore(defaults: defaults),
            handoffStore: ScheduleHandoffStore(directoryURL: directory)
        )

        XCTAssertNil(store.activeDocument)
        XCTAssertTrue(store.todayBlocks.isEmpty)
    }

    func testMarkdownScheduleImportIsGenericStableAndAllowsLateBlocks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2030, month: 1, day: 2, hour: 10)))
        let text = """
        | Time | Task | Exact actions | Finish target |
        |---|---|---|---|
        | 6:00–6:30 PM | Dinner | Eat away from the desk. | Meal complete. |
        | 6:30–7:30 PM | Programming study | Solve one bounded exercise. | One tested program. |
        | 11:00–11:30 PM | Wind down | Put devices away. | Devices away. |
        | 11:30 PM–7:00 AM | Sleep | Protect rest. | Rest complete. |
        """

        let first = try ScheduleImportParser(calendar: calendar).parse(text, for: date)
        let second = try ScheduleImportParser(calendar: calendar).parse(text, for: date)

        XCTAssertEqual(first.date, "2030-01-02")
        XCTAssertEqual(first.blocks.count, 4)
        XCTAssertEqual(first.blocks[1].category, .competition)
        XCTAssertEqual(first.blocks[1].competition?.rawValue, "Programming study")
        XCTAssertTrue(first.blocks[1].resources.contains(ScheduleResourceCatalog.terminal))
        XCTAssertEqual(first.blocks.map(\.id), second.blocks.map(\.id))
        XCTAssertEqual(first.blocks[2].endMinute, 23 * 60 + 30)
    }

    func testScheduleImportRejectsOverlap() {
        let text = """
        8:00 PM–9:00 PM\tStudy block\tSolve.\tThree problems.
        8:30 PM–9:30 PM\tPractice block\tReview.\tOne artifact.
        """
        XCTAssertThrowsError(try ScheduleImportParser().parse(text)) { error in
            guard case ScheduleImportError.overlap = error else {
                return XCTFail("Expected overlap, received \(error)")
            }
        }
    }

    func testScheduleImportRejectsOverlapWithCrossMidnightSleep() {
        let text = """
        6:30 AM–7:30 AM\tMorning routine\tGet ready.\tReady by 7:30 AM.
        11:00 PM–7:00 AM\tSleep\tProtect rest.\tEight hours protected.
        """
        XCTAssertThrowsError(try ScheduleImportParser().parse(text)) { error in
            guard case ScheduleImportError.overlap = error else {
                return XCTFail("Expected cross-midnight overlap, received \(error)")
            }
        }
    }

    func testResourceSafetyAllowsHTTPSLocalhostAndBundleIDsOnly() {
        XCTAssertTrue(ResourceTarget.url("Docs", "https://example.com/guide").isSafeToOpen)
        XCTAssertTrue(ResourceTarget.url("Local", "http://localhost:3000").isSafeToOpen)
        XCTAssertFalse(ResourceTarget.url("Insecure", "http://example.com").isSafeToOpen)
        XCTAssertFalse(ResourceTarget.url("File", "file:///tmp/private").isSafeToOpen)
        XCTAssertFalse(ResourceTarget.url("Credentials", "https://user:secret@localhost").isSafeToOpen)
        XCTAssertTrue(ResourceTarget.application("Editor", bundleIdentifier: "com.example.Editor").isSafeToOpen)
        XCTAssertFalse(ResourceTarget.application("Bad", bundleIdentifier: "Editor;open").isSafeToOpen)
        XCTAssertFalse(ResourceTarget.application("Bad", bundleIdentifier: "com..Editor").isSafeToOpen)
    }

    func testMoreTimeRequestUsesConfiguredHardStopAndExplicitRollover() {
        let target = block(id: "focus", title: "Focus", start: 20 * 60, end: 21 * 60, category: .competition)
        let breakBlock = block(id: "break", title: "Break", start: 21 * 60, end: 22 * 60, category: .routine)
        let deepWork = block(id: "deep", title: "Deep work", start: 22 * 60, end: 23 * 60, category: .research)
        let sleep = block(id: "sleep", title: "Sleep", start: 23 * 60, end: 7 * 60, category: .sleep)

        let proposal = ScheduleAdjustmentEngine.proposal(
            extending: target,
            by: 30,
            in: [target, breakBlock, deepWork, sleep],
            hardStopMinute: 23 * 60
        )

        XCTAssertTrue(proposal.canApply)
        XCTAssertEqual(proposal.rolloverTitles, ["Deep work"])
        XCTAssertEqual(proposal.proposedBlocks.first { $0.id == "focus" }?.endMinute, 21 * 60 + 30)
        XCTAssertEqual(proposal.proposedBlocks.first { $0.category == .sleep }?.startMinute, 23 * 60)
    }

    func testMoreTimeRequestCannotMoveFixedCommitment() {
        let target = block(id: "focus", title: "Focus", start: 20 * 60, end: 21 * 60, category: .competition)
        let meeting = block(id: "meeting", title: "Meeting", start: 21 * 60, end: 22 * 60, category: .extracurricular)
        let proposal = ScheduleAdjustmentEngine.proposal(
            extending: target,
            by: 30,
            in: [target, meeting],
            hardStopMinute: 23 * 60
        )

        XCTAssertFalse(proposal.canApply)
        XCTAssertTrue(proposal.summary.contains("fixed"))
    }

    @MainActor
    func testHandoffStoreUsesPrivateFileAndLoadsOnlyMatchingDate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyHandoffTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2030, month: 1, day: 2, hour: 12)))
        let document = DailyScheduleDocument(
            date: "2030-01-02",
            refreshedAt: "2030-01-02T15:00:00Z",
            source: "Local test",
            blocks: [block(id: "work", title: "Work", start: 12 * 60, end: 13 * 60, category: .routine)]
        )
        let store = ScheduleHandoffStore(directoryURL: directory)

        try store.write(document)
        XCTAssertEqual(try store.load(for: date, calendar: calendar), document)
        let permissions = try FileManager.default.attributesOfItem(atPath: store.handoffURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)

        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))
        XCTAssertThrowsError(try store.load(for: tomorrow, calendar: calendar)) { error in
            guard case ScheduleImportError.wrongDate = error else {
                return XCTFail("Expected wrong-date failure, received \(error)")
            }
        }
    }

    @MainActor
    func testCompletionPersistsLocallyForImportedBlock() throws {
        let suiteName = "TopBuddyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyScheduleTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2030, month: 1, day: 2, hour: 12, minute: 15)))
        let handoff = ScheduleHandoffStore(directoryURL: directory)
        let importedBlock = block(id: "work", title: "Work", start: 12 * 60, end: 13 * 60, category: .routine)
        try handoff.write(DailyScheduleDocument(
            date: "2030-01-02",
            refreshedAt: "2030-01-02T15:00:00Z",
            source: "Local test",
            blocks: [importedBlock]
        ))
        let progress = ProgressStore(defaults: defaults, calendar: calendar)
        let store = ScheduleStore(now: date, calendar: calendar, progressStore: progress, handoffStore: handoff)

        let current = try XCTUnwrap(store.currentBlock)
        XCTAssertFalse(store.isCompleted(current))
        store.toggleCompletion(current)
        XCTAssertTrue(store.isCompleted(current))
    }

    func testCodexExecutableOverrideResolvesWithoutCredentialAccess() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyCodexTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("codex")
        XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data("#!/bin/sh\n".utf8)))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let resolved = CodexBridge.resolveExecutable(
            environment: ["TOPBUDDY_CODEX_PATH": executable.path, "PATH": ""],
            fileManager: .default
        )
        XCTAssertEqual(resolved?.standardizedFileURL, executable.standardizedFileURL)
    }

    func testCodexCoachUsesAnEphemeralEmptyWorkingDirectory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyCodexWorkingDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("codex")
        let script = """
        #!/bin/sh
        output=""
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--output-last-message" ]; then
            shift
            output="$1"
          fi
          shift
        done
        pwd > "$output"
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let response = try await CodexBridge(executableURL: executable)
            .ask(question: "What is next?", scheduleContext: "No active block")

        XCTAssertTrue(response.contains("topbuddy-codex-"))
        XCTAssertFalse(response.contains(FileManager.default.homeDirectoryForCurrentUser.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: response))
    }

    func testMoreTimeIntentParsesMinutesAndHours() {
        XCTAssertEqual(MoreTimeRequestParser.minutes(in: "I need 25 more minutes"), 25)
        XCTAssertEqual(MoreTimeRequestParser.minutes(in: "extend this by 1 hour"), 60)
        XCTAssertNil(MoreTimeRequestParser.minutes(in: "What should I do next?"))
    }

    func testCommunityPetMetadataAndTrustedGalleryURL() throws {
        let data = Data(
            """
            {
              "id": "marshmallow",
              "displayName": "Marshmallow",
              "description": "Fluffy companion",
              "kind": "dog",
              "tags": ["fluffy"],
              "spriteVersionNumber": 2,
              "ownerName": "Creator",
              "ownerHandle": "creator",
              "spritesheetUrl": "https://codex-pets.net/pets/marshmallow/spritesheet.webp",
              "posterUrl": "https://codex-pets.net/pets/marshmallow/poster.webp",
              "downloadUrl": "https://codex-pets.net/api/pets/marshmallow/download"
            }
            """.utf8
        )
        let pet = try JSONDecoder().decode(CommunityPet.self, from: data)
        XCTAssertEqual(pet.attribution, "by creator")
        XCTAssertTrue(pet.isVersionSupported)

        let client = CodexPetsClient()
        let url = try client.galleryURL(query: " fluffy ", page: 0, pageSize: 500)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(components.host, "codex-pets.net")
        XCTAssertEqual(items["page"]!, "1")
        XCTAssertEqual(items["pageSize"]!, "48")
        XCTAssertEqual(items["q"]!, "fluffy")
    }

    func testPetClientRejectsUntrustedAssets() {
        let client = CodexPetsClient()
        XCTAssertThrowsError(try client.trustedURL(from: "https://example.com/pet.webp"))
        XCTAssertThrowsError(try client.trustedURL(from: "http://codex-pets.net/pet.webp"))
        XCTAssertNoThrow(try client.trustedURL(from: "/pets/marshmallow/spritesheet.webp"))
    }

    func testPetIdentifiersCannotEscapePrivateLibrary() {
        XCTAssertTrue(PetLibraryStorage.isValidPetID("local-pet-123"))
        XCTAssertFalse(PetLibraryStorage.isValidPetID("../escape"))
        XCTAssertFalse(PetLibraryStorage.isValidPetID("UPPERCASE"))
        XCTAssertFalse(PetLibraryStorage.isValidPetID("pet name"))
    }

    func testStaticPetImageImportDetection() throws {
        let onePixelPNG = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        XCTAssertEqual(try PetLibraryStorage.inspectImportedAsset(onePixelPNG), .staticImage)
        XCTAssertThrowsError(try PetLibraryStorage.inspectImportedAsset(Data("not an image".utf8)))
    }

    func testNotchGeometryAnchorsFramesToScreenTop() {
        let geometry = NotchDisplayGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 958),
            safeAreaTop: 38,
            auxiliaryLeftWidth: 650,
            auxiliaryRightWidth: 650
        )
        XCTAssertEqual(geometry.physicalNotchWidth, 216)
        XCTAssertEqual(geometry.windowFrame(expanded: false).maxY, geometry.screenFrame.maxY)
        XCTAssertEqual(geometry.windowFrame(expanded: true).midX, geometry.screenFrame.midX)
    }

    @MainActor
    func testNotchPresentationHoverClickPinAndCollapse() {
        let geometry = NotchDisplayGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 876),
            safeAreaTop: 32,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil
        )
        let presentation = NotchPresentationStore(geometry: geometry)
        presentation.expand(reason: .hover)
        XCTAssertTrue(presentation.isExpanded)
        XCTAssertFalse(presentation.isPinned)
        presentation.expand(reason: .click, page: .shelf)
        XCTAssertTrue(presentation.isPinned)
        presentation.collapse()
        XCTAssertFalse(presentation.isExpanded)
    }

    @MainActor
    func testFileShelfPersistsPrivateDeduplicatedReferences() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopBuddyShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("first.txt")
        try Data("one".utf8).write(to: file)
        let shelf = FileShelfStore(directoryURL: directory)
        XCTAssertEqual(shelf.add(urls: [file, file]), 1)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("file-shelf.json").path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testNotionInputAllowsOnlySecureNotionHosts() {
        XCTAssertEqual(NotionURLPolicy.notionURL(from: "app.notion.com/p/example")?.absoluteString, "https://app.notion.com/p/example")
        XCTAssertNotNil(NotionURLPolicy.notionURL(from: "https://workspace.notion.site/Planner-123"))
        XCTAssertNil(NotionURLPolicy.notionURL(from: "http://www.notion.so/"))
        XCTAssertNil(NotionURLPolicy.notionURL(from: "https://example.com/"))
    }

    func testMusicPlaybackAndPlaylistParsers() throws {
        let separator = "\u{001E}"
        let snapshot = try MusicPlaybackSnapshot(serialized: [
            "playing", "Song", "Artist", "Album", "215", "71", "45", "true", "off"
        ].joined(separator: separator))
        XCTAssertTrue(snapshot.shouldShowCompactNowPlaying)
        XCTAssertEqual(snapshot.volume, 45)

        let playlist = try MusicPlaylist(serializedRow: ["87F567CDDC5F25C3", "Focus", "25", "5400"].joined(separator: separator))
        XCTAssertEqual(playlist.name, "Focus")
        XCTAssertFalse(MusicPlaylist.isValidPersistentID("ABC\"; delete every track"))
    }

    @MainActor
    func testOptionalMediaAndCalendarIntegrationsCanBeDisabledLocally() throws {
        let suiteName = "TopBuddyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "topbuddy.music.controls-enabled")

        let music = MusicHubStore(defaults: defaults)
        let calendar = CalendarAgendaStore(defaults: defaults)
        music.disableControls()
        calendar.disable()

        XCTAssertFalse(music.controlsEnabled)
        XCTAssertFalse(calendar.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "topbuddy.music.controls-enabled"))
        XCTAssertFalse(defaults.bool(forKey: "topbuddy.calendar.enabled"))
    }

    private func block(
        id: String,
        title: String,
        start: Int,
        end: Int,
        category: BlockCategory
    ) -> ScheduleBlock {
        ScheduleBlock(
            id: id,
            title: title,
            startMinute: start,
            endMinute: end,
            category: category,
            exactActions: "Do the bounded action.",
            finishTarget: "One saved artifact.",
            resources: [],
            competition: nil
        )
    }
}
