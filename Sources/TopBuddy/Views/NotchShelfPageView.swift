import AppKit
import SwiftUI

struct NotchShelfPageView: View {
    @ObservedObject var shelf: FileShelfStore
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("FILE SHELF", systemImage: "tray.full.fill")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.orange)
                Spacer()
                Text("References only · files never move")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                if !shelf.items.isEmpty {
                    Button("Clean missing", systemImage: "sparkles") { shelf.removeMissingReferences() }
                        .controlSize(.small)
                }
            }

            if shelf.items.isEmpty {
                dropTarget
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        dropTile
                        ForEach(shelf.items) { item in
                            shelfTile(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let error = shelf.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: shelf.receive)
    }

    private var dropTarget: some View {
        VStack(spacing: 10) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "arrow.down.doc.fill")
                .font(.system(size: 36))
                .foregroundStyle(isTargeted ? .cyan : .white.opacity(0.55))
            Text(isTargeted ? "Drop to add" : "Drag files into the notch")
                .font(.headline)
            Text("TopBuddy saves private references so you can open, reveal, or share them later. It does not copy, delete, or relocate the originals.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, minHeight: 155)
        .background(Color.white.opacity(isTargeted ? 0.11 : 0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .foregroundStyle(isTargeted ? .cyan : .white.opacity(0.16))
        }
    }

    private var dropTile: some View {
        VStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
            Text("Drop more")
                .font(.caption.weight(.semibold))
        }
        .frame(width: 96, height: 124)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(.white.opacity(0.16))
        }
    }

    private func shelfTile(_ item: ShelfItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
            Text(item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack(spacing: 9) {
                Button { shelf.open(item) } label: { Image(systemName: "arrow.up.forward.app") }
                    .help("Open")
                Button { shelf.reveal(item) } label: { Image(systemName: "magnifyingglass") }
                    .help("Reveal in Finder")
                Button { shelf.share(item, from: NSApp.keyWindow?.contentView) } label: { Image(systemName: "square.and.arrow.up") }
                    .help("Share or AirDrop")
                Button(role: .destructive) { shelf.remove(item) } label: { Image(systemName: "xmark") }
                    .help("Remove shelf reference")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 132, height: 124, alignment: .leading)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button("Open", action: { shelf.open(item) })
            Button("Reveal in Finder", action: { shelf.reveal(item) })
            Divider()
            Button("Remove reference", role: .destructive, action: { shelf.remove(item) })
        }
    }
}
