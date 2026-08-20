import SwiftUI

enum PetDesign {
    static let contentSpacing: CGFloat = 18
    static let cardRadius: CGFloat = 18
    static let compactRadius: CGFloat = 13
}

/// Shared visual and interaction metrics for the top-anchored notch surface.
/// Keep these values centralized so a page cannot accidentally regress to a
/// glyph-sized click target or a slightly different black than the shell.
enum TopBuddyNotchDesign {
    /// A calibrated near-black matches the perceived camera housing on the
    /// built-in display while keeping every notch page on one exact surface.
    static let shellColor = Color(.sRGB, red: 0.012, green: 0.012, blue: 0.014, opacity: 1)
    static let minimumHitTarget: CGFloat = 44
    static let denseHitTarget: CGFloat = 34
}

struct TopBuddyNotchIconButtonStyle: ButtonStyle {
    var size = TopBuddyNotchDesign.minimumHitTarget
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .contentShape(Circle())
            .background(
                Color.white.opacity(
                    configuration.isPressed ? 0.18 : (emphasized ? 0.12 : 0.04)
                ),
                in: Circle()
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TopBuddyNotchTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 13)
            .frame(minHeight: TopBuddyNotchDesign.minimumHitTarget)
            .contentShape(Capsule())
            .background(
                Color.white.opacity(configuration.isPressed ? 0.16 : 0.07),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
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
