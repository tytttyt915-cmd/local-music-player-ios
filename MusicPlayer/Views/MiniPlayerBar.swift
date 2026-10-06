import SwiftUI

/// v3 底部悬浮迷你播放条：封面 + 歌名 + 上一曲/播放/下一曲
/// 对标参考 App 的胶囊形悬浮条
struct MiniPlayerBar: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var theme: ThemeSettings
    let onTap: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // 封面
                    MiniCover(track: track)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()

                    // 上一曲
                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // 播放/暂停
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    // 下一曲
                    Button { _ = player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            // 进度细条
            .overlay(alignment: .bottom) {
                if player.duration > 0 {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(player.currentTime / player.duration),
                                   height: 2)
                            .padding(.horizontal, 28)
                    }
                    .frame(height: 2)
                }
            }
        }
    }
}

/// 迷你封面：本地/自定义/在线
struct MiniCover: View {
    let track: Track
    @State private var onlineImage: UIImage?

    var body: some View {
        Group {
            if let data = track.displayArtworkData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let img = onlineImage {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(colors: [.pink.opacity(0.7), .purple.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
        }
        .task(id: track.id) {
            if track.displayArtworkData == nil, let url = track.artworkURL {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    onlineImage = img
                }
            } else {
                onlineImage = nil
            }
        }
    }
}
