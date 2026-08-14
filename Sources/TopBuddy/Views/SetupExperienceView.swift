import SwiftUI

struct SetupExperienceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var schedule: ScheduleStore

    @State private var step = 0
    @State private var preset: ControlPreset = .assist
    @State private var showNotch = true
    @State private var autoOpenResources = false
    @State private var autoHideDistractions = false
    @State private var quitReviewEnabled = true
    @State private var notionEnabled = false
    @State private var codexEnabled = false
    @State private var requestMusicAccess = false
    @State private var requestCalendarAccess = false
    @State private var hardStopMinute = 23 * 60
    @State private var showsPetGallery = false
    @State private var showsScheduleImport = false
    @State private var isFinishing = false

    private let stepTitles = ["Welcome", "Control", "Connections", "Personalize"]

    var body: some View {
        VStack(spacing: 0) {
            setupHeader
            Divider()
            ScrollView {
                page
                    .frame(maxWidth: 860, alignment: .leading)
                    .padding(34)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            setupFooter
        }
        .frame(minWidth: 880, minHeight: 650)
        .sheet(isPresented: $showsPetGallery) {
            PetGalleryView(library: model.petLibrary)
        }
        .sheet(isPresented: $showsScheduleImport) {
            ScheduleImportView()
                .environmentObject(schedule)
        }
    }

    private var setupHeader: some View {
        HStack(spacing: 16) {
            PetAvatarView(state: .ready, library: model.petLibrary, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("Set up TopBuddy")
                    .font(.title2.weight(.semibold))
                Text("Step \(step + 1) of \(stepTitles.count) · \(stepTitles[step])")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Private by default")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                ProgressView(value: Double(step + 1), total: Double(stepTitles.count))
                    .frame(width: 190)
            }
        }
        .padding(22)
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case 0: welcomePage
        case 1: controlPage
        case 2: connectionsPage
        default: personalizePage
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text("A schedule companion that earns control")
                    .font(.largeTitle.weight(.bold))
                Text("TopBuddy can live in the MacBook notch, open the tools a block needs, hide distractions, coach a stuck session, and control Apple Music. You decide which parts exist on this Mac.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 14)], alignment: .leading, spacing: 14) {
                promise("No bundled personal data", "The public app starts with no schedule, accounts, workspace links, or example history.", "person.crop.circle.badge.xmark")
                promise("No telemetry", "TopBuddy has no analytics SDK, ad tracker, or remote account of its own.", "waveform.path.ecg.rectangle")
                promise("No surprise automation", "Automatic opening, hiding, Music, Calendar, and Codex all begin disabled.", "hand.raised.fill")
            }

            Label("You can revisit every choice in Settings. Quitting another app always requires a fresh review and uses the app's normal quit request.", systemImage: "lock.shield.fill")
                .foregroundStyle(.secondary)
                .padding(16)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var controlPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageTitle("How much control should TopBuddy have?", "Choose a starting preset, then customize each switch.")

            HStack(alignment: .top, spacing: 14) {
                ForEach(ControlPreset.allCases) { option in
                    Button {
                        choose(option)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(option.title)
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                Image(systemName: preset == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(preset == option ? Color.accentColor : Color.secondary)
                            }
                            Text(option.summary)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                        .background(preset == option ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(preset == option ? Color.accentColor : Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Form {
                Section("Notch and focus") {
                    Toggle("Show TopBuddy in the notch", isOn: $showNotch)
                    Toggle("Open block resources automatically", isOn: $autoOpenResources)
                    Toggle("Hide unrelated apps at block changes", isOn: $autoHideDistractions)
                    Toggle("Show manual app-quit review tools", isOn: $quitReviewEnabled)
                }
                Section("Boundary") {
                    Picker("Schedule hard stop", selection: $hardStopMinute) {
                        ForEach(Array(stride(from: 18 * 60, through: 24 * 60, by: 30)), id: \.self) { minute in
                            Text(timeLabel(minute)).tag(minute)
                        }
                    }
                    Text("Auto-hide never quits apps. Quit tools never run without selecting apps and confirming again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var connectionsPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            pageTitle("Choose optional connections", "None are required. Credentials stay in the owning app or local WebKit session.")

            VStack(spacing: 12) {
                connectionToggle("Notion workspace", "Open Notion in TopBuddy's local WebKit view. Its cookies never enter schedule or coach files.", "doc.text", isOn: $notionEnabled)
                connectionToggle("Codex schedule coach", "Use an already-installed Codex CLI only when you send a message, with an ephemeral read-only sandbox.", "sparkles", isOn: $codexEnabled)
                connectionToggle("Apple Music controls", "Request macOS Automation access for fixed playback, seek, volume, shuffle, and playlist commands.", "music.note", isOn: $requestMusicAccess)
                connectionToggle("Apple Calendar agenda", "Request read access to show upcoming events in the notch. TopBuddy never creates or edits events.", "calendar", isOn: $requestCalendarAccess)
            }

            Label(
                requestMusicAccess || requestCalendarAccess
                    ? "Finish Setup will trigger only the macOS permission dialogs selected above."
                    : "No operating-system permission dialog will be requested.",
                systemImage: "checkmark.shield.fill"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var personalizePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageTitle("Make it yours", "Both steps are optional. The app works with a placeholder pet and an empty day.")

            HStack(alignment: .top, spacing: 16) {
                setupCard(
                    title: "Choose or import a pet",
                    subtitle: model.petLibrary.selectedPet == nil
                        ? "Browse community pets or import a local image or compatible sprite sheet."
                        : "Using \(model.petLibrary.selectedName) · \(model.petLibrary.selectedAttribution)",
                    systemImage: "pawprint.fill",
                    actionTitle: "Open pet library"
                ) { showsPetGallery = true }

                setupCard(
                    title: "Import today's schedule",
                    subtitle: schedule.activeDocument == nil
                        ? "Paste a four-column Markdown or TSV plan. Nothing is preloaded."
                        : "Loaded \(schedule.todayBlocks.count) local blocks from \(schedule.activeDocument?.source ?? "your import").",
                    systemImage: "tablecells",
                    actionTitle: schedule.activeDocument == nil ? "Import schedule" : "Review import"
                ) { showsScheduleImport = true }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("What stays on this Mac", systemImage: "internaldrive.fill")
                    .font(.headline)
                Text("Schedule, completion state, pet assets, focus-kit rules, and WebKit data are stored locally. TopBuddy never bundles your imported content into updates or GitHub reports.")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var setupFooter: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
            }
            Spacer()
            if step < stepTitles.count - 1 {
                Button("Continue") { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(finishTitle) {
                    finish()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isFinishing)
            }
        }
        .padding(18)
    }

    private var finishTitle: String {
        if isFinishing { return "Finishing…" }
        return requestMusicAccess || requestCalendarAccess
            ? "Finish & request selected access"
            : "Finish setup"
    }

    private func pageTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.weight(.bold))
            Text(subtitle).font(.title3).foregroundStyle(.secondary)
        }
    }

    private func promise(_ title: String, _ subtitle: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.cyan)
            Text(title).font(.headline)
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func connectionToggle(
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            Toggle(title, isOn: isOn).labelsHidden()
        }
        .padding(16)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private func setupCard(
        title: String,
        subtitle: String,
        systemImage: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.tint)
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func choose(_ option: ControlPreset) {
        preset = option
        showNotch = option.showNotch
        autoOpenResources = option.autoOpenResources
        autoHideDistractions = option.autoHideDistractions
        quitReviewEnabled = option.quitReviewEnabled
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        Task { @MainActor in
            if requestMusicAccess {
                await model.musicHub.enableControls()
            } else {
                model.musicHub.disableControls()
            }
            if requestCalendarAccess {
                await model.calendarAgenda.requestAccess()
            } else {
                model.calendarAgenda.disable()
            }
            model.completeOnboarding(
                showNotch: showNotch,
                autoOpenResources: autoOpenResources,
                autoHideDistractions: autoHideDistractions,
                quitReviewEnabled: quitReviewEnabled,
                notionWorkspaceEnabled: notionEnabled,
                codexCoachEnabled: codexEnabled,
                hardStopMinute: hardStopMinute
            )
            isFinishing = false
        }
    }

    private func timeLabel(_ minute: Int) -> String {
        let normalized = minute % (24 * 60)
        let hour24 = normalized / 60
        let minutePart = normalized % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minutePart, suffix)
    }
}
