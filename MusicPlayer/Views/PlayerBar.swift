import SwiftUI

/// 底部悬浮胶囊播放条
struct PlayerBar: View {
    @EnvironmentObject private var player: AudioPlayerManager
    var onTap: () -> Void = {}

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 12) {
                ArtworkView(track: track)
                    .frame(width: 44, height: 44)
                    .cornerRadius(22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button { _ = player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.cyan.opacity(0.25), lineWidth: 1))
            .shadow(color: .cyan.opacity(0.18), radius: 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .onTapGesture(perform: onTap)
        }
    }
}
