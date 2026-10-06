import SwiftUI

struct TrackRow: View {
    let track: Track
    var onTap: () -> Void = {}

    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var favorites: FavoriteStore

    private var isCurrent: Bool { player.currentTrack?.id == track.id }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track: track)
                .frame(width: 48, height: 48)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCurrent ? .cyan : .white)
                        .lineLimit(1)
                    if track.isOnline {
                        Image(systemName: "cloud")
                            .font(.caption2)
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                }
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.durationText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)

            Button {
                favorites.toggle(track)
            } label: {
                Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                    .foregroundColor(favorites.isFavorite(track) ? .pink : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrent ? Color.white.opacity(0.09) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
