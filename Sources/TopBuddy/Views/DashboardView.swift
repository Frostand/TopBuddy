import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Environment(\.openWindow) private var openWindow
    @SceneStorage("topbuddy.selected-block") private var selectedBlockID: String?
    @State private var showsQuitReview = false
    @State private var showsScheduleImport = false
    @State private var showsResourceRules = false
    @State private var showsPetGallery = false

    private var selectedBlock: ScheduleBlock? {
        schedule.todayBlocks.first { $0.id == selectedBlockID }
            ?? schedule.currentBlock
            ?? schedule.todayBlocks.first
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, idealWidth: 1_100, minHeight: 640, idealHeight: 760)
        .onAppear { repairSelection() }
        .onChange(of: schedule.revision) { _, _ in repairSelection() }
        .onChange(of: schedule.currentBlock?.id) { previous, current in
            if selectedBlockID == nil || selectedBlockID == previous {
                selectedBlockID = current
            }
        }
        .sheet(isPresented: $showsQuitReview) {
            AppQuitReviewView()
                .environmentObject(model)
        }
        .sheet(isPresented: $showsScheduleImport) {
            ScheduleImportView()
                .environmentObject(schedule)
        }
        .sheet(isPresented: $showsResourceRules) {
            ResourceRulesView(initialBlockID: selectedBlock?.id)
                .environmentObject(schedule)
        }
        .sheet(isPresented: $showsPetGallery) {
            PetGalleryView(library: model.petLibrary)
        }
    }

    private var sidebar: some View {
        List(selection: $selectedBlockID) {
            Section {
                HStack(spacing: 12) {
                    PetAvatarView(state: schedule.petState, library: model.petLibrary, size: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TopBuddy")
                            .font(.headline)
                        Text(schedule.petState.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(schedule.petState.accent)
                        Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Day progress")
                        Spacer()
                        Text("\(completedCount)/\(schedule.todayBlocks.count)")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    ProgressView(value: dayProgress)
                        .tint(schedule.petState.accent)
                        .accessibilityLabel("Day progress")
                        .accessibilityValue("\(completedCount) of \(schedule.todayBlocks.count) blocks completed")
                }
                .padding(.vertical, 4)
            }

            Section("Today") {
                ForEach(schedule.todayBlocks) { block in
                    ScheduleRowView(
                        block: block,
                        isCurrent: schedule.currentBlock?.id == block.id,
                        isCompleted: schedule.isCompleted(block)
                    )
                    .tag(block.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 320)
        .safeAreaInset(edge: .bottom) {
            sourceStatus
        }
    }

    private var sourceStatus: some View {
        HStack(spacing: 9) {
            Image(systemName: schedule.activeDocument == nil ? "bolt.horizontal.circle" : "checkmark.circle.fill")
                .foregroundStyle(schedule.activeDocument == nil ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(schedule.activeDocument?.source ?? "No schedule")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(schedule.activeDocument == nil ? "Import a local plan" : "Local plan loaded")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .help(schedule.handoffMessage)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PetDesign.contentSpacing) {
                dayHeader

                if let block = selectedBlock {
                    CurrentBlockCard(
                        block: block,
                        isCurrent: schedule.currentBlock?.id == block.id,
                        editResources: { showsResourceRules = true }
                    )
                } else {
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "No schedule blocks",
                            systemImage: "calendar.badge.plus",
                            description: Text("TopBuddy ships empty. Paste your own four-column schedule to begin.")
                        )
                        Button("Import today's schedule", systemImage: "square.and.arrow.down") {
                            showsScheduleImport = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .petSurface()
                }

                if model.codexCoachEnabled {
                    CodexCoachView()
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Codex coaching is off")
                                .font(.headline)
                            Text("Enable it in Settings when you want user-initiated, read-only schedule coaching.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        SettingsLink { Text("Settings") }
                    }
                    .petSurface()
                }

                if !schedule.rolloverTitles.isEmpty {
                    rolloverCard
                }
            }
            .frame(maxWidth: 820)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("TopBuddy")
        .toolbar { toolbarContent }
    }

    private var dayHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.title2.weight(.semibold))
                Text(model.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            PetStatusBadge(text: "Hard stop · \(model.hardStopLabel)", color: .purple, systemImage: "moon.stars.fill")
        }
    }

    private var rolloverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Approved local rollover", systemImage: "arrowshape.turn.up.right.fill")
                .font(.headline)
            ForEach(Array(schedule.rolloverTitles.enumerated()), id: \.offset) { index, title in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.orange)
                    Text(title)
                }
            }
            Text("Local to TopBuddy; connected services stay unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .petSurface()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.toggleLockInMode(for: selectedBlock)
            } label: {
                Label(
                    model.lockInModeEnabled ? "End Lock In" : "Lock In",
                    systemImage: model.lockInModeEnabled ? "lock.open.fill" : "lock.fill"
                )
            }
            .help(model.lockInModeEnabled ? "End Lock In immediately" : "Protect the selected block's exact focus kit")

            Button {
                openWindow(id: "workspace-hub")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Workspace Hub", systemImage: "square.grid.2x2")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .help("Open optional Notion and Apple Music integrations")

            Button {
                showsScheduleImport = true
            } label: {
                Label("Import schedule", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .help("Paste or import today's schedule")

            Menu {
                Toggle("TopBuddy notch", isOn: $model.floatingPetEnabled)
                Toggle("Auto-open resources", isOn: $model.autoOpenResources)
                Toggle("Auto-hide distractions", isOn: $model.autoHideDistractions)

                Button(model.lockInModeEnabled ? "Show Lock In browser" : "Start Lock In") {
                    if model.lockInModeEnabled {
                        model.showLockInWindow()
                    } else {
                        model.toggleLockInMode(for: selectedBlock)
                    }
                }

                Divider()

                Button("Choose pet…") { showsPetGallery = true }
                Button("Edit focus kit…") { showsResourceRules = true }
                if model.quitReviewEnabled {
                    Button("Review apps to quit…") {
                        model.refreshRunningApps()
                        showsQuitReview = true
                    }
                }

                Divider()

                SettingsLink {
                    Label("Settings…", systemImage: "gearshape")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .help("Focus and app settings")
        }
    }

    private var completedCount: Int {
        schedule.todayBlocks.filter { schedule.isCompleted($0) }.count
    }

    private var dayProgress: Double {
        guard !schedule.todayBlocks.isEmpty else { return 0 }
        return Double(completedCount) / Double(schedule.todayBlocks.count)
    }

    private func repairSelection() {
        guard !schedule.todayBlocks.isEmpty else {
            selectedBlockID = nil
            return
        }
        if selectedBlockID == nil || !schedule.todayBlocks.contains(where: { $0.id == selectedBlockID }) {
            selectedBlockID = schedule.currentBlock?.id ?? schedule.todayBlocks.first?.id
        }
    }
}
