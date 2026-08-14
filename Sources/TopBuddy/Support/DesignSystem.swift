import SwiftUI

enum PetDesign {
    static let contentSpacing: CGFloat = 18
    static let cardRadius: CGFloat = 18
    static let compactRadius: CGFloat = 13
}

struct PetSurfaceModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PetDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PetDesign.cardRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.075), lineWidth: 1)
            }
    }
}

extension View {
    func petSurface(padding: CGFloat = 18) -> some View {
        modifier(PetSurfaceModifier(padding: padding))
    }
}

struct PetStatusBadge: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct PetSectionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
