import SwiftUI
import UniformTypeIdentifiers

struct TopBuddyNotchView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var schedule: ScheduleStore
    @ObservedObject var presentation: NotchPresentationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if presentation.isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                compactView
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            TopBuddyNotchShape(expanded: presentation.isExpanded)
                .fill(TopBuddyNotchDesign.shellColor)
                .shadow(
                    color: presentation.isExpanded ? Color.black.opacity(0.46) : .clear,
                    radius: 20,
                    y: 12
                )
        }
        .clipShape(TopBuddyNotchShape(expanded: presentation.isExpanded))
        .contentShape(TopBuddyNotchShape(expanded: presentation.isExpanded))
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .snappy(duration: 0.27), value: presentation.isExpanded)
        .onTapGesture {
            if !presentation.isExpanded {
                presentation.expand(
                    reason: .click,
                    page: model.musicHub.snapshot.shouldShowCompactNowPlaying ? .music : nil
                )
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            presentation.expand(reason: .drop, page: .shelf)
            return model.fileShelf.receive(providers)
        }
        .onChange(of: isDropTargeted) { _, targeted in
            if targeted { presentation.expand(reason: .drop, page: .shelf) }
        }
        .task {
            model.calendarAgenda.refresh()
            await model.musicHub.monitorPlayback()
        }
    }

    private var compactView: some View {
        HStack(spacing: 8) {
            if model.musicHub.snapshot.shouldShowCompactNowPlaying {
                MusicArtworkView(
                    artworkData: model.musicHub.artworkData,
                    cornerRadius: 6,
                    symbolSize: 11
                )
                .frame(width: 26, height: 26)
            } else {
                PetAvatarView(state: schedule.petState, library: model.petLibrary, size: 26)
            }

            Spacer(minLength: max(110, presentation.geometry.physicalNotchWidth - 28))

            if model.musicHub.snapshot.shouldShowCompactNowPlaying {
                MusicActivityBars(
                    isPlaying: true,
                    color: schedule.petState.accent,
                    maximumHeight: 14
                )
                .frame(width: 22)
            } else if let block = schedule.currentBlock {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(schedule.petState.accent)
                            .frame(width: 5, height: 5)
                        Text(shortCountdown(for: block, at: context.date))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: presentation.geometry.closedSize.height, alignment: .center)
        .help(
            model.musicHub.snapshot.shouldShowCompactNowPlaying
                ? "\(model.musicHub.snapshot.trackName) — hover or click for Apple Music"
                : "TopBuddy · hover or click to open"
        )
        .accessibilityLabel(compactAccessibilityLabel)
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            notchHeader
                .frame(height: max(52, presentation.geometry.physicalNotchHeight + 14))

            pageBar
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

            Divider().overlay(Color.white.opacity(0.09))

            pageContent
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var notchHeader: some View {
        HStack(spacing: 10) {
            PetAvatarView(state: schedule.petState, library: model.petLibrary, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("TOPBUDDY")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.cyan)
                Text(schedule.currentBlock?.title ?? "Nothing active")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            Button {
                presentation.togglePin()
            } label: {
                Image(systemName: presentation.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(TopBuddyNotchIconButtonStyle())
            .foregroundStyle(presentation.isPinned ? .cyan : .white.opacity(0.68))
            .help(presentation.isPinned ? "Unpin from notch" : "Keep TopBuddy open")
            .accessibilityLabel(presentation.isPinned ? "Unpin TopBuddy" : "Pin TopBuddy")

            Button {
                presentation.collapse()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(TopBuddyNotchIconButtonStyle())
            .foregroundStyle(.white.opacity(0.68))
            .help("Collapse into the notch")
            .accessibilityLabel("Collapse TopBuddy")
        }
        .padding(.horizontal, 16)
    }

    private var pageBar: some View {
        HStack(spacing: 6) {
            ForEach(TopBuddyNotchPage.allCases) { page in
                Button {
                    presentation.selectedPage = page
                } label: {
                    Label(page.title, systemImage: page.systemImage)
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: TopBuddyNotchDesign.minimumHitTarget)
                        .contentShape(Capsule())
                        .background(
                            presentation.selectedPage == page ? Color.white.opacity(0.14) : .clear,
                            in: Capsule()
                        )
                        .foregroundStyle(presentation.selectedPage == page ? .white : .white.opacity(0.58))
                }
                .buttonStyle(.plain)
                .help(page.title)
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch presentation.selectedPage {
        case .buddy:
            NotchBuddyPageView(presentation: presentation)
        case .music:
            NotchMusicPageView(music: model.musicHub)
        case .agenda:
            NotchAgendaPageView(calendarAgenda: model.calendarAgenda)
        case .shelf:
            NotchShelfPageView(shelf: model.fileShelf)
        case .focus:
            NotchFocusPageView(focus: model.focusUtility)
        }
    }

    private func shortCountdown(for block: ScheduleBlock, at date: Date) -> String {
        let seconds = Int(schedule.secondsRemaining(in: block, at: date))
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private var compactAccessibilityLabel: String {
        if model.musicHub.snapshot.shouldShowCompactNowPlaying {
            return "Apple Music playing \(model.musicHub.snapshot.trackName) by \(model.musicHub.snapshot.artistName). Hover or click to open controls."
        }
        return "TopBuddy notch. Hover or click to open."
    }
}

private struct TopBuddyNotchShape: Shape {
    let expanded: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = expanded ? 25 : 14
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
