import SwiftUI

struct PetAvatarView: View {
    let state: PetState
    @ObservedObject var library: PetLibraryStore
    var size: CGFloat = 150

    var body: some View {
        Group {
            if let pet = library.selectedPet,
               let spritesheet = library.selectedSpritesheet {
                if pet.pet.kind == "local-static" {
                    Image(nsImage: spritesheet)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
                } else {
                    CommunityPetSpriteView(
                        petID: pet.id,
                        spritesheet: spritesheet,
                        state: state,
                        size: size
                    )
                }
            } else {
                PetPlaceholderView(size: size)
                    .overlay(alignment: .bottomTrailing) {
                        if library.installingPetID != nil {
                            ProgressView()
                                .controlSize(.small)
                                .padding(3)
                                .background(.regularMaterial, in: Circle())
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(library.selectedName) is \(state.label.lowercased())")
        .help("\(library.selectedName) · \(library.selectedAttribution)")
    }
}
