import AppKit
import SwiftUI

struct MusicArtworkView: View {
    let artworkData: Data?
    var cornerRadius: CGFloat = 14
    var symbolSize: CGFloat = 24

    var body: some View {
        Group {
            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.indigo, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: symbolSize, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
        .accessibilityHidden(true)
    }
}

struct MusicActivityBars: View {
    let isPlaying: Bool
    var color: Color = .indigo
    var maximumHeight: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 0.14,
                paused: !isPlaying || reduceMotion
            )
        ) { context in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.8, height: barHeight(index: index, at: context.date))
                }
            }
            .frame(height: maximumHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Apple Music is playing" : "Apple Music is paused")
    }

    private func barHeight(index: Int, at date: Date) -> CGFloat {
        guard isPlaying, !reduceMotion else {
            let fractions: [CGFloat] = [0.42, 0.78, 0.56, 0.9]
            return max(3, maximumHeight * fractions[index])
        }
        let time = date.timeIntervalSinceReferenceDate
        let frequency = 3.2 + Double(index) * 0.72
        let phase = Double(index) * 1.18
        let normalized = (sin(time * frequency + phase) + 1) / 2
        return 3 + (maximumHeight - 3) * normalized
    }
}
