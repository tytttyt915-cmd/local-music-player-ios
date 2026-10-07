import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var theme: ThemeSettings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("关闭") { dismiss() }.padding()
            }
            Spacer()
            if let track = player.currentTrack {
                Text(track.title).font(.title).foregroundColor(theme.textColor)
                Text(track.artist).foregroundColor(theme.secondaryTextColor)
            }
            Spacer()
            HStack(spacing: 40) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.title)
                }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.title)
                }
            }
            .foregroundColor(theme.textColor)
            Spacer()
        }
        .background(theme.backgroundColor.ignoresSafeArea())
    }
}
