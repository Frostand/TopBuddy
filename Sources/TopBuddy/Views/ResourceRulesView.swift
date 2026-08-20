import SwiftUI

struct ResourceRulesView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    let initialBlockID: String?

    @State private var selectedBlockID: String?
    @State private var resources: [ResourceTarget] = []
    @State private var materials: [StudyMaterial] = []
    @State private var customKind: ResourceTarget.Kind = .url
    @State private var customLabel = ""
    @State private var customValue = ""
    @State private var materialKind: StudyMaterial.Kind = .book
    @State private var materialLabel = ""
    @State private var materialDetail = ""
    @State private var errorMessage = ""

    init(initialBlockID: String? = nil) {
        self.initialBlockID = initialBlockID
        _selectedBlockID = State(initialValue: initialBlockID)
    }

    private var selectedBlock: ScheduleBlock? {
        schedule.todayBlocks.first { $0.id == selectedBlockID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(20)

            Divider()

            HSplitView {
                List(selection: $selectedBlockID) {
                    Section("Today's blocks") {
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
                .frame(minWidth: 230, idealWidth: 260)

                resourceEditor
                    .frame(minWidth: 500)
            }

            Divider()

            footer
                .padding(14)
        }
        .frame(minWidth: 820, minHeight: 600)
        .onAppear {
            selectedBlockID = initialBlockID ?? schedule.currentBlock?.id ?? schedule.todayBlocks.first?.id
            loadSelection()
        }
        .onChange(of: selectedBlockID) { _, _ in loadSelection() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("Focus kits")
                    .font(.title2.weight(.semibold))
                Text("Choose exactly what TopBuddy opens, allows, and tells you to bring for each block.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PetStatusBadge(text: "Never auto-quits", color: .green, systemImage: "lock.shield.fill")
        }
    }

    private var resourceEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedBlock?.title ?? "Select a block")
                        .font(.title2.weight(.semibold))
                    if let selectedBlock {
                        Text(selectedBlock.timeLabel)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    PetSectionLabel(title: "Allowed apps and websites", systemImage: "checkmark.shield")
                    if resources.isEmpty {
                        ContentUnavailableView(
                            "No resources assigned",
                            systemImage: "square.dashed",
                            description: Text("Use a quick add below or enter a custom website or app bundle ID.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ForEach(resources) { resource in
                            HStack(spacing: 11) {
                                Image(systemName: resource.kind == .url ? "link" : "app")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resource.label)
                                        .font(.callout.weight(.medium))
                                    Text(resource.value)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Toggle(
                                    "Open at start",
                                    isOn: Binding(
                                        get: { resource.openAtStart },
                                        set: { updateOpenAtStart(resource, value: $0) }
                                    )
                                )
                                .toggleStyle(.checkbox)
                                .controlSize(.small)
                                Button(role: .destructive) {
                                    resources.removeAll { $0.id == resource.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove \(resource.label)")
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    PetSectionLabel(title: "Quick add", systemImage: "plus.circle")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(ScheduleResourceCatalog.templates) { resource in
                            Button {
                                add(resource)
                            } label: {
                                Label(resource.label, systemImage: resource.kind == .url ? "link" : "app")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .disabled(resources.contains(where: { $0.id == resource.id }))
                        }
                    }
                }

                GroupBox("Custom resource") {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            Text("Type")
                            Picker("Type", selection: $customKind) {
                                Text("Website URL").tag(ResourceTarget.Kind.url)
                                Text("App bundle ID").tag(ResourceTarget.Kind.application)
                            }
                            .labelsHidden()
                        }
                        GridRow {
                            Text("Label")
                            TextField("Example: School portal", text: $customLabel)
                        }
                        GridRow {
                            Text(customKind == .url ? "URL" : "Bundle ID")
                            TextField(customKind == .url ? "https://…" : "com.example.App", text: $customValue)
                        }
                    }
                    .padding(.vertical, 5)

                    HStack {
                        Spacer()
                        Button("Add resource", systemImage: "plus") { addCustomResource() }
                            .disabled(!canAddCustomResource)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    PetSectionLabel(title: "Books, files, and physical materials", systemImage: "book.closed")
                    if materials.isEmpty {
                        Text("No offline materials assigned.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(materials) { material in
                            HStack(spacing: 10) {
                                Image(systemName: material.kind.systemImage)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(material.label)
                                        .font(.callout.weight(.medium))
                                    Text(material.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    materials.removeAll { $0.id == material.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }

                GroupBox("Add material") {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            Text("Type")
                            Picker("Type", selection: $materialKind) {
                                ForEach(StudyMaterial.Kind.allCases, id: \.self) { kind in
                                    Text(kind.rawValue.capitalized).tag(kind)
                                }
                            }
                            .labelsHidden()
                        }
                        GridRow {
                            Text("Label")
                            TextField("Example: Omega textbook", text: $materialLabel)
                        }
                        GridRow {
                            Text("Details")
                            TextField("Example: Chapter 2, pages 27–40", text: $materialDetail)
                        }
                    }
                    .padding(.vertical, 5)

                    HStack {
                        Spacer()
                        Button("Add material", systemImage: "plus") { addMaterial() }
                            .disabled(!canAddMaterial)
                    }
                }

                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(22)
        }
    }

    private var footer: some View {
        HStack {
            Text("Lock In hides unlisted apps and only opens assigned links in your macOS default browser. It cannot inspect or block manual navigation there without an extension, and it never force-quits anything.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save focus kit") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedBlock == nil)
        }
    }

    private var canAddCustomResource: Bool {
        let resource = ResourceTarget(
            kind: customKind,
            label: customLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            value: customValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return !resource.label.isEmpty && !resource.value.isEmpty && resource.isSafeToOpen
    }

    private func loadSelection() {
        resources = selectedBlock?.resources ?? []
        materials = selectedBlock?.materials ?? []
        errorMessage = ""
    }

    private func add(_ resource: ResourceTarget) {
        guard !resources.contains(where: { $0.id == resource.id }) else { return }
        resources.append(resource)
    }

    private func addCustomResource() {
        guard canAddCustomResource else {
            errorMessage = "Use an HTTPS URL, an HTTP localhost URL, or a valid application bundle ID."
            return
        }
        add(
            ResourceTarget(
                kind: customKind,
                label: customLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                value: customValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        customLabel = ""
        customValue = ""
    }

    private var canAddMaterial: Bool {
        StudyMaterial(
            kind: materialKind,
            label: materialLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: materialDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        ).isValid
    }

    private func addMaterial() {
        let material = StudyMaterial(
            kind: materialKind,
            label: materialLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: materialDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard material.isValid, !materials.contains(material) else { return }
        materials.append(material)
        materialLabel = ""
        materialDetail = ""
    }

    private func updateOpenAtStart(_ resource: ResourceTarget, value: Bool) {
        guard let index = resources.firstIndex(where: { $0.id == resource.id }) else { return }
        resources[index] = resource.replacingOpenAtStart(value)
    }

    private func save() {
        guard let selectedBlockID else { return }
        do {
            try schedule.updateFocusKit(
                for: selectedBlockID,
                resources: resources,
                materials: materials
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
