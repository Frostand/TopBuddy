import SwiftUI
import UniformTypeIdentifiers

struct PetGalleryView: View {
    @ObservedObject var library: PetLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showsImporter = false

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            gallery
            Divider()
            footer
        }
        .frame(width: 900, height: 650)
        .task {
            if library.catalog.isEmpty {
                await library.refreshCatalog()
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.image]) { result in
            if case let .success(url) = result {
                library.importPet(from: url)
            } else if case let .failure(error) = result {
                library.errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Choose TopBuddy's pet")
                    .font(.title2.weight(.semibold))
                Text("Animated community pets from codex-pets.net")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !library.installedPets.isEmpty {
                Menu(library.selectedName, systemImage: "checkmark.circle") {
                    ForEach(library.installedPets) { pet in
                        Button(pet.pet.displayName) { library.select(pet) }
                    }
                }
            }

            Button("Import…", systemImage: "square.and.arrow.down") {
                showsImporter = true
            }

            TextField("Search pets", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit { search() }

            Button("Search", systemImage: "magnifyingglass") { search() }
                .disabled(library.isLoading)
        }
        .padding(18)
    }

    @ViewBuilder
    private var gallery: some View {
        if library.isLoading && library.catalog.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading community pets…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.catalog.isEmpty {
            ContentUnavailableView(
                "No pets found",
                systemImage: "pawprint",
                description: Text("Try a different search or reload the gallery.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if let error = library.errorMessage {
                    errorBanner(error)
                        .padding(.bottom, 12)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(library.catalog) { pet in
                        CommunityPetCard(
                            pet: pet,
                            isSelected: library.selectedPet?.id == pet.id,
                            isInstalled: library.installedIDs.contains(pet.id),
                            isInstalling: library.installingPetID == pet.id,
                            usePet: { Task { await library.use(pet) } }
                        )
                    }
                }
            }
            .padding(18)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label("Community pets download only after you choose Use", systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("•")
                .foregroundStyle(.tertiary)
            Text("Community uploads; creators assert sharing rights. Avoid branded characters unless you have permission.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Link("Open full gallery", destination: CodexPetsClient.productionBaseURL)
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
            Button("Dismiss") { library.clearError() }
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func search() {
        Task { await library.refreshCatalog(query: query) }
    }
}

private struct CommunityPetCard: View {
    let pet: CommunityPet
    let isSelected: Bool
    let isInstalled: Bool
    let isInstalling: Bool
    let usePet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            poster

            VStack(alignment: .leading, spacing: 3) {
                Text(pet.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(pet.attribution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(pet.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            }

            HStack {
                if isInstalled && !isSelected {
                    Label("Installed", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: usePet) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(isSelected ? "Using" : "Use", systemImage: isSelected ? "checkmark" : "arrow.down.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSelected || isInstalling)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        }
    }

    @ViewBuilder
    private var poster: some View {
        AsyncImage(url: try? CodexPetsClient().trustedURL(from: pet.posterUrl)) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            case .failure:
                Image(systemName: "pawprint.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("\(pet.displayName) preview")
    }
}
