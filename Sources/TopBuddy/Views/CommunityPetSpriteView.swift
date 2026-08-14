import AppKit
import SwiftUI

struct PetAnimationSpec: Equatable, Sendable {
    let row: Int
    let frames: Int

    static func forState(_ state: PetState) -> PetAnimationSpec {
        switch state {
        case .ready: PetAnimationSpec(row: 0, frames: 6)
        case .focusing: PetAnimationSpec(row: 8, frames: 6)
        case .traveling: PetAnimationSpec(row: 7, frames: 6)
        case .eating: PetAnimationSpec(row: 6, frames: 6)
        case .celebrating: PetAnimationSpec(row: 3, frames: 4)
        case .resting: PetAnimationSpec(row: 0, frames: 6)
        case .needsAttention: PetAnimationSpec(row: 5, frames: 8)
        }
    }
}

struct CommunityPetSpriteView: View {
    let petID: String
    let spritesheet: NSImage
    let state: PetState
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let animation = PetAnimationSpec.forState(state)
        TimelineView(.animation(minimumInterval: 0.26, paused: reduceMotion)) { context in
            let frame = reduceMotion
                ? 0
                : Int(context.date.timeIntervalSinceReferenceDate / 0.26) % animation.frames
            if let image = PetSpriteFrameCache.frame(
                petID: petID,
                spritesheet: spritesheet,
                row: animation.row,
                frame: frame
            ) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                PetPlaceholderView(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

struct PetPlaceholderView: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

@MainActor
private enum PetSpriteFrameCache {
    private static let cellWidth = 192
    private static let cellHeight = 208
    private static let cache = NSCache<NSString, NSImage>()

    static func frame(
        petID: String,
        spritesheet: NSImage,
        row: Int,
        frame: Int
    ) -> NSImage? {
        let key = "\(petID)-\(row)-\(frame)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        var proposedRect = CGRect(origin: .zero, size: spritesheet.size)
        guard let source = spritesheet.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        let x = frame * cellWidth
        let y = source.height - ((row + 1) * cellHeight)
        guard x >= 0, y >= 0,
              x + cellWidth <= source.width,
              y + cellHeight <= source.height,
              let cropped = source.cropping(to: CGRect(x: x, y: y, width: cellWidth, height: cellHeight)) else {
            return nil
        }

        let image = NSImage(cgImage: cropped, size: NSSize(width: cellWidth, height: cellHeight))
        cache.setObject(image, forKey: key)
        return image
    }
}
