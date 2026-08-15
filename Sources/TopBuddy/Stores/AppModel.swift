import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let schedule: ScheduleStore
    let workspace: WorkspaceController
    let codex: CodexBridge
    let speech: SpeechController
    let petLibrary: PetLibraryStore
    let musicHub: MusicHubStore
    let fileShelf: FileShelfStore
    let focusUtility: FocusUtilityStore
    let calendarAgenda: CalendarAgendaStore
    let lockIn: LockInStore
    let focusBrowser: FocusBrowserStore

    @Published var onboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(onboardingComplete, forKey: Self.onboardingKey)
            if !onboardingComplete { hideFloatingPet() }
        }
    }

    @Published var autoOpenResources: Bool {
        didSet { UserDefaults.standard.set(autoOpenResources, forKey: Self.autoOpenKey) }
    }
    @Published var autoHideDistractions: Bool {
        didSet { UserDefaults.standard.set(autoHideDistractions, forKey: Self.autoHideKey) }
    }
    @Published var floatingPetEnabled: Bool {
        didSet {
            UserDefaults.standard.set(floatingPetEnabled, forKey: Self.floatingPetKey)
            if floatingPetEnabled { showFloatingPet() } else { hideFloatingPet() }
        }
    }
    @Published var speakReplies: Bool {
        didSet {
            UserDefaults.standard.set(speakReplies, forKey: Self.speakRepliesKey)
            if !speakReplies { speech.stop() }
        }
    }
    @Published var quitReviewEnabled: Bool {
        didSet { UserDefaults.standard.set(quitReviewEnabled, forKey: Self.quitReviewKey) }
    }
    @Published var notionWorkspaceEnabled: Bool {
        didSet { UserDefaults.standard.set(notionWorkspaceEnabled, forKey: Self.notionWorkspaceKey) }
    }
    @Published var codexCoachEnabled: Bool {
        didSet { UserDefaults.standard.set(codexCoachEnabled, forKey: Self.codexCoachKey) }
    }
    @Published var hardStopMinute: Int {
        didSet {
            UserDefaults.standard.set(hardStopMinute, forKey: Self.hardStopKey)
        }
    }
    @Published var lockInModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(lockInModeEnabled, forKey: Self.lockInModeKey)
            if lockInModeEnabled {
                startLockInMonitoring()
            } else {
                stopLockIn()
            }
        }
    }
    @Published var statusMessage = "TopBuddy is ready."
    @Published var codexResponse = ""
    @Published var codexIsRunning = false
    @Published var selectedQuitBundleIDs: Set<String> = []
    @Published private(set) var coachMessages: [CoachMessage] = [
        CoachMessage(role: .pet, text: "Tell me what is stuck, ask for the next step, or say “I need 20 more minutes.” I will propose schedule changes before applying them.")
    ]
    @Published var pendingAdjustment: ScheduleAdjustmentProposal?

    private static let autoOpenKey = "topbuddy.auto-open-resources"
    private static let autoHideKey = "topbuddy.auto-hide-distractions"
    private static let floatingPetKey = "topbuddy.floating-pet"
    private static let speakRepliesKey = "topbuddy.speak-replies"
    private static let onboardingKey = "topbuddy.onboarding-complete"
    private static let quitReviewKey = "topbuddy.quit-review-enabled"
    private static let notionWorkspaceKey = "topbuddy.notion-workspace-enabled"
    private static let codexCoachKey = "topbuddy.codex-coach-enabled"
    private static let hardStopKey = "topbuddy.hard-stop-minute"
    private static let lockInModeKey = "topbuddy.lock-in-mode"
    private var monitorTask: Task<Void, Never>?
    private var lockInMonitorTask: Task<Void, Never>?
    private var lastObservedBlockKey: String?
    private var notchPanelController: TopBuddyNotchPanelController?
    private var lockInBrowserController: LockInBrowserWindowController?

    init(
        schedule: ScheduleStore? = nil,
        workspace: WorkspaceController? = nil,
        codex: CodexBridge = CodexBridge(),
        speech: SpeechController = SpeechController(),
        petLibrary: PetLibraryStore? = nil,
        musicHub: MusicHubStore? = nil,
        fileShelf: FileShelfStore? = nil,
        focusUtility: FocusUtilityStore? = nil,
        calendarAgenda: CalendarAgendaStore? = nil,
        lockIn: LockInStore? = nil
    ) {
        let defaults = UserDefaults.standard
        let lockInStore = lockIn ?? LockInStore()
        self.schedule = schedule ?? ScheduleStore()
        let workspaceController = workspace ?? WorkspaceController()
        self.workspace = workspaceController
        self.codex = codex
        self.speech = speech
        self.petLibrary = petLibrary ?? PetLibraryStore()
        self.musicHub = musicHub ?? MusicHubStore()
        self.fileShelf = fileShelf ?? FileShelfStore()
        self.focusUtility = focusUtility ?? FocusUtilityStore()
        self.calendarAgenda = calendarAgenda ?? CalendarAgendaStore()
        self.lockIn = lockInStore
        self.focusBrowser = FocusBrowserStore(
            lockIn: lockInStore,
            defaultBrowserRouter: workspaceController.defaultBrowserRouter
        )
        self.onboardingComplete = defaults.bool(forKey: Self.onboardingKey)
        self.autoOpenResources = defaults.bool(forKey: Self.autoOpenKey)
        self.autoHideDistractions = defaults.bool(forKey: Self.autoHideKey)
        self.floatingPetEnabled = defaults.bool(forKey: Self.floatingPetKey)
        self.speakReplies = defaults.bool(forKey: Self.speakRepliesKey)
        self.quitReviewEnabled = defaults.bool(forKey: Self.quitReviewKey)
        self.notionWorkspaceEnabled = defaults.bool(forKey: Self.notionWorkspaceKey)
        self.codexCoachEnabled = defaults.bool(forKey: Self.codexCoachKey)
        let savedHardStop = defaults.integer(forKey: Self.hardStopKey)
        self.hardStopMinute = savedHardStop == 0
            ? 23 * 60
            : min(24 * 60, max(18 * 60, savedHardStop))
        self.lockInModeEnabled = defaults.bool(forKey: Self.lockInModeKey)
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        schedule.reloadHandoff(force: true)
        observeBlockTransition(allowAutomation: false)
        Task { [weak self] in
            await self?.petLibrary.prepare()
        }
        if onboardingComplete && floatingPetEnabled { showFloatingPet() }
        if lockInModeEnabled { startLockInMonitoring() }
        if lockInModeEnabled, let block = schedule.currentBlock {
            prepareLockIn(for: block, showWindow: false)
        }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                self.schedule.refresh()
                self.observeBlockTransition(allowAutomation: true)
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        lockInMonitorTask?.cancel()
        lockInMonitorTask = nil
    }

    func showFloatingPet() {
        guard onboardingComplete else { return }
        if notchPanelController == nil {
            notchPanelController = TopBuddyNotchPanelController(model: self)
        }
        notchPanelController?.show()
    }

    func hideFloatingPet() {
        notchPanelController?.hide()
    }

    func toggleFloatingPet() {
        if notchPanelController?.isVisible == true {
            floatingPetEnabled = false
        } else {
            floatingPetEnabled = true
        }
    }

    func openNotch(page: TopBuddyNotchPage = .buddy) {
        guard onboardingComplete else { return }
        if notchPanelController == nil {
            notchPanelController = TopBuddyNotchPanelController(model: self)
        }
        floatingPetEnabled = true
        notchPanelController?.open(page: page)
    }

    func startCurrentBlock() {
        guard let block = schedule.currentBlock else {
            statusMessage = "There is no active block to start."
            return
        }
        start(block)
    }

    func start(_ block: ScheduleBlock) {
        if lockInModeEnabled {
            guard schedule.currentBlock?.id == block.id else {
                statusMessage = "Lock In can protect only the block happening now."
                return
            }
            prepareLockIn(for: block, showWindow: false)
            return
        }
        workspace.prepare(block: block, hideDistractions: autoHideDistractions)
        statusMessage = "Started \(block.title). \(workspace.lastActionSummary)"
    }

    func open(_ resource: ResourceTarget, for block: ScheduleBlock) {
        if lockInModeEnabled {
            guard schedule.currentBlock?.id == block.id else {
                statusMessage = "That resource belongs to a different block and remains blocked."
                return
            }
            let expectedPolicy = LockInPolicy(
                block: block,
                additionalAllowedBundleIdentifiers: workspace.allowedBundleIdentifiers(for: block)
            )
            if lockIn.activePolicy != expectedPolicy {
                lockIn.configure(
                    for: block,
                    additionalAllowedBundleIdentifiers: expectedPolicy.allowedBundleIdentifiers
                )
                focusBrowser.configure(for: block, preserveLockInPolicy: true)
            }
            switch resource.kind {
            case .url:
                guard resource.isSafeToOpen,
                      let url = URL(string: resource.value) else {
                    statusMessage = "That link is not a safe HTTPS or localhost resource."
                    return
                }
                guard lockIn.allows(url: url) else {
                    lockIn.registerBlockedWebsite(url: url)
                    statusMessage = "That website is outside this block's Lock In focus kit."
                    showLockInWindow()
                    return
                }
                workspace.open([resource])
                statusMessage = "Opened \(resource.label) in \(workspace.currentDefaultBrowser.name)."
            case .application:
                guard lockIn.allowedBundleIdentifiers().contains(resource.value) else {
                    statusMessage = "That app is not in this block's Lock In focus kit."
                    return
                }
                workspace.open([resource])
            }
        } else {
            workspace.open([resource])
        }
    }

    func toggleLockInMode(for block: ScheduleBlock? = nil) {
        if lockInModeEnabled {
            lockInModeEnabled = false
            statusMessage = "Lock In ended. No apps were quit."
        } else {
            let candidate = block ?? schedule.currentBlock
            if let candidate, schedule.currentBlock?.id != candidate.id {
                statusMessage = "Lock In can protect only the block happening now."
                return
            }
            lockInModeEnabled = true
            guard let candidate else {
                statusMessage = "Lock In is on and waiting for the next schedule block."
                return
            }
            prepareLockIn(for: candidate, showWindow: false)
        }
    }

    func showLockInWindow() {
        if lockInBrowserController == nil {
            lockInBrowserController = LockInBrowserWindowController(
                browser: focusBrowser,
                lockIn: lockIn,
                onEndLockIn: { [weak self] in
                    self?.lockInModeEnabled = false
                },
                onGranted: { [weak self] attempt in
                    self?.resume(after: attempt)
                }
            )
        }
        lockInBrowserController?.show()
    }

    func hideDistractionsNow() {
        hideDistractions(for: schedule.currentBlock)
    }

    func hideDistractions(for block: ScheduleBlock?) {
        let required = block.map { workspace.allowedBundleIdentifiers(for: $0) } ?? []
        workspace.hideUnrelatedApps(keeping: required)
        statusMessage = workspace.lastActionSummary
    }

    func toggleCurrentCompletion() {
        guard let block = schedule.currentBlock else { return }
        toggleCompletion(block)
    }

    func toggleCompletion(_ block: ScheduleBlock) {
        schedule.toggleCompletion(block)
        statusMessage = schedule.isCompleted(block)
            ? "Marked \(block.title) complete locally."
            : "Reopened \(block.title) locally."
    }

    func refreshRunningApps() {
        workspace.refreshRunningApps()
        selectedQuitBundleIDs = selectedQuitBundleIDs.intersection(
            Set(workspace.runningApps.map(\.bundleIdentifier))
        )
    }

    func requestQuitSelectedApps() {
        guard quitReviewEnabled else {
            statusMessage = "App quit tools are disabled in Settings."
            return
        }
        let names = workspace.requestGracefulQuit(bundleIdentifiers: selectedQuitBundleIDs)
        selectedQuitBundleIDs.removeAll()
        statusMessage = names.isEmpty
            ? "No apps were asked to quit."
            : "Sent normal quit requests to \(names.joined(separator: ", "))."
    }

    func askCodex(_ question: String) {
        sendCoachMessage(question)
    }

    func sendCoachMessage(_ message: String) {
        guard codexCoachEnabled else {
            statusMessage = "Codex coaching is disabled in Settings."
            return
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !codexIsRunning else { return }
        coachMessages.append(CoachMessage(role: .user, text: trimmed))

        if MoreTimeRequestParser.isMoreTimeIntent(trimmed) {
            guard let minutes = MoreTimeRequestParser.minutes(in: trimmed) else {
                appendPetMessage("How many extra minutes do you need? Try “I need 20 more minutes.” I will show the consequence before changing today.")
                return
            }
            guard let proposal = schedule.adjustmentProposal(minutes: minutes, hardStopMinute: hardStopMinute) else {
                appendPetMessage("There is no active schedule block to extend right now.")
                return
            }
            pendingAdjustment = proposal
            appendPetMessage(proposal.summary)
            return
        }

        guard codex.isAvailable else {
            let message = CodexBridgeError.executableNotFound.localizedDescription
            codexResponse = message
            appendPetMessage(message)
            return
        }

        codexIsRunning = true
        codexResponse = ""
        let context = scheduleContext()
        Task {
            do {
                let response = try await codex.ask(question: trimmed, scheduleContext: context)
                codexResponse = response
                appendPetMessage(response)
            } catch {
                codexResponse = error.localizedDescription
                appendPetMessage(error.localizedDescription)
            }
            codexIsRunning = false
        }
    }

    func applyPendingAdjustment() {
        guard let proposal = pendingAdjustment else { return }
        do {
            try schedule.apply(proposal)
            pendingAdjustment = nil
            statusMessage = "Applied the approved local schedule change."
            appendPetMessage("Applied. The local today.json changed; no connected service was edited.")
        } catch {
            appendPetMessage("I could not apply that change: \(error.localizedDescription)")
        }
    }

    func cancelPendingAdjustment() {
        pendingAdjustment = nil
        appendPetMessage("Canceled. Today's schedule is unchanged.")
    }

    private func appendPetMessage(_ text: String) {
        coachMessages.append(CoachMessage(role: .pet, text: text))
        if speakReplies { speech.speak(text) }
        if coachMessages.count > 30 {
            coachMessages.removeFirst(coachMessages.count - 30)
        }
    }

    var hardStopLabel: String {
        Self.timeLabel(hardStopMinute)
    }

    func completeOnboarding(
        showNotch: Bool,
        autoOpenResources: Bool,
        autoHideDistractions: Bool,
        lockInModeEnabled: Bool,
        quitReviewEnabled: Bool,
        notionWorkspaceEnabled: Bool,
        codexCoachEnabled: Bool,
        hardStopMinute: Int
    ) {
        self.autoOpenResources = autoOpenResources
        self.autoHideDistractions = autoHideDistractions
        self.lockInModeEnabled = lockInModeEnabled
        self.quitReviewEnabled = quitReviewEnabled
        self.notionWorkspaceEnabled = notionWorkspaceEnabled
        self.codexCoachEnabled = codexCoachEnabled
        self.hardStopMinute = min(24 * 60, max(18 * 60, hardStopMinute))
        self.onboardingComplete = true
        self.floatingPetEnabled = showNotch
        statusMessage = schedule.todayBlocks.isEmpty
            ? "Setup complete. Import a schedule when you are ready."
            : "Setup complete. Your local schedule is ready."
    }

    func restartOnboarding() {
        onboardingComplete = false
        statusMessage = "Setup reopened. Existing local schedules and pets were preserved."
    }

    private func observeBlockTransition(allowAutomation: Bool) {
        guard let block = schedule.currentBlock else {
            suspendLockInIfNeeded()
            return
        }
        let dateKey = ScheduleImportParser.dateKey(for: schedule.now)
        let key = "\(dateKey)|\(block.id)"
        guard key != lastObservedBlockKey else { return }
        lastObservedBlockKey = key
        statusMessage = "Now: \(block.title)"
        if allowAutomation && lockInModeEnabled {
            prepareLockIn(for: block, showWindow: false)
        } else if allowAutomation && autoOpenResources {
            workspace.prepare(block: block, hideDistractions: autoHideDistractions)
            statusMessage = "TopBuddy prepared \(block.title). \(workspace.lastActionSummary)"
        } else if allowAutomation && autoHideDistractions {
            hideDistractions(for: block)
        }
    }

    private func scheduleContext() -> String {
        let current = schedule.currentBlock.map {
            "Current: \($0.timeLabel) — \($0.title)\nActions: \($0.exactActions)\nFinish target: \($0.finishTarget)\nResources: \($0.resources.map(\.label).joined(separator: ", "))\nMaterials: \($0.materials.map { "\($0.label): \($0.detail)" }.joined(separator: ", "))\nLock In: \(lockInModeEnabled ? "active" : "off")"
        } ?? "Current: no active block"
        let next = schedule.nextBlock.map {
            "Next: \($0.timeLabel) — \($0.title)\nFinish target: \($0.finishTarget)"
        } ?? "Next: unavailable"
        let recentConversation = coachMessages.suffix(6).map {
            "\($0.role == .user ? "User" : "TopBuddy"): \($0.text)"
        }.joined(separator: "\n")
        return "\(current)\n\n\(next)\n\nLocal rollover: \(schedule.rolloverTitles.joined(separator: ", "))\n\nRecent conversation:\n\(recentConversation)\n\nHard stop: \(hardStopLabel). Never overlap blocks or move work into sleep. Propose changes; do not claim they were applied."
    }

    private static func timeLabel(_ minute: Int) -> String {
        let normalized = minute % (24 * 60)
        let hour24 = normalized / 60
        let minutePart = normalized % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minutePart, suffix)
    }

    private func prepareLockIn(for block: ScheduleBlock, showWindow: Bool) {
        let allowedBundleIdentifiers = workspace.allowedBundleIdentifiers(for: block)
        lockIn.configure(
            for: block,
            additionalAllowedBundleIdentifiers: allowedBundleIdentifiers
        )
        focusBrowser.configure(for: block, preserveLockInPolicy: true)
        workspace.prepare(
            block: block,
            hideDistractions: true,
            strictAllowlist: true
        )
        startLockInMonitoring()
        if showWindow {
            showLockInWindow()
        }
        statusMessage = "Locked in to \(block.title). Approved links open in \(workspace.currentDefaultBrowser.name); nothing was quit."
    }

    private func startLockInMonitoring() {
        guard lockInModeEnabled, lockInMonitorTask == nil else { return }
        lockInMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(700))
                guard let self, self.lockInModeEnabled else { return }
                self.enforceLockIn()
            }
        }
    }

    private func stopLockIn() {
        lockInMonitorTask?.cancel()
        lockInMonitorTask = nil
        lockIn.stop()
        lockInBrowserController?.close()
    }

    private func enforceLockIn() {
        guard let block = schedule.currentBlock else {
            suspendLockInIfNeeded()
            return
        }
        let expectedPolicy = LockInPolicy(
            block: block,
            additionalAllowedBundleIdentifiers: workspace.allowedBundleIdentifiers(for: block)
        )
        if lockIn.activePolicy != expectedPolicy {
            prepareLockIn(for: block, showWindow: false)
        }
        let allowed = lockIn.allowedBundleIdentifiers()
        guard let blocked = workspace.blockFrontmostApplication(keeping: allowed) else { return }
        if lockIn.registerBlockedApplication(
            name: blocked.name,
            bundleIdentifier: blocked.bundleIdentifier
        ) {
            statusMessage = "Lock In blocked \(blocked.name). Add a specific timed reason if it is necessary."
            showLockInWindow()
        }
    }

    private func resume(after attempt: LockInAttempt) {
        switch attempt.kind {
        case .application:
            workspace.open([
                .application(attempt.label, bundleIdentifier: attempt.value)
            ])
        case .website:
            let resource = ResourceTarget.url(attempt.label, attempt.value)
            guard resource.isSafeToOpen else { return }
            workspace.open([resource])
        }
    }

    private func suspendLockInIfNeeded() {
        guard lockIn.isActive else { return }
        lockIn.stop()
        lockInBrowserController?.close()
        statusMessage = "Lock In is on and waiting for the next schedule block."
    }
}
